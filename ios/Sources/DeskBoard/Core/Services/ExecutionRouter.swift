import Foundation
import UIKit

nonisolated struct ActionRoutingContext: Sendable {
    let commandID: UUID
    let traceID: String
    let attempt: Int
    let maxAttempts: Int
    let targetPolicy: ActionTargetPolicy
    let fallbackPolicy: BackgroundFallbackPolicy
    let ttlSeconds: Int?
}

nonisolated struct DeferredExecutionAction: Sendable {
    let action: ButtonAction
    let context: ActionRoutingContext
    let queuedAt: Date
}

nonisolated struct RoutedExecutionResult: Sendable {
    let status: RemoteActionStatus
    let detail: String?
    let executor: CommandExecutor
    let queuePosition: Int?
    let errorCode: String?
    let latencyMs: Int?
}

@MainActor
final class ExecutionRouter {
    static let shared = ExecutionRouter()

    private struct DedupRecord {
        let result: RoutedExecutionResult
        let expiresAt: Date
    }

    private var dedupCache: [UUID: DedupRecord] = [:]
    private let dedupMaxEntries = 2048
    private let dedupTTLSeconds: TimeInterval = 180

    private init() {}

    func route(
        action: ButtonAction,
        context: ActionRoutingContext,
        sourceDeviceName: String,
        executeLocal: @escaping @MainActor (ButtonAction) async -> ExecutionResult,
        enqueueDeferred: @MainActor (DeferredExecutionAction) -> Int
    ) async -> RoutedExecutionResult {
        pruneDedupCache()

        if let duplicate = dedupCache[context.commandID],
           duplicate.expiresAt > Date() {
            return duplicate.result
        }

        let start = Date()
        let relayFirst = context.targetPolicy == .preferMac || context.targetPolicy == .lastActiveCapable
        if relayFirst {
            let relay = await tryRelay(
                action: action,
                sourceDeviceName: sourceDeviceName,
                reason: "target_policy_prefer_mac",
                traceID: context.traceID,
                attempt: context.attempt,
                ttlSeconds: context.ttlSeconds
            )
            if relay.success {
                let forwarded = RoutedExecutionResult(
                    status: .forwarded,
                    detail: relay.detail ?? "Executed via Mac relay",
                    executor: .macRelay,
                    queuePosition: nil,
                    errorCode: nil,
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: forwarded)
                return forwarded
            }
            if context.targetPolicy == .preferMac && context.fallbackPolicy == .fail {
                let failed = RoutedExecutionResult(
                    status: .failed,
                    detail: relay.detail ?? "Mac relay failed",
                    executor: .macRelay,
                    queuePosition: nil,
                    errorCode: relay.errorCode ?? "relay_failed",
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: failed)
                return failed
            }
        }

        if action.requiresForegroundOnIOSReceiver,
           UIApplication.shared.applicationState != .active {
            switch context.fallbackPolicy {
            case .relay:
                let relay = await tryRelay(
                    action: action,
                    sourceDeviceName: sourceDeviceName,
                    reason: "receiver_background_foreground_required",
                    traceID: context.traceID,
                    attempt: context.attempt,
                    ttlSeconds: context.ttlSeconds
                )
                if relay.success {
                    let forwarded = RoutedExecutionResult(
                        status: .forwarded,
                        detail: relay.detail ?? "Executed via Mac relay",
                        executor: .macRelay,
                        queuePosition: nil,
                        errorCode: nil,
                        latencyMs: elapsedMS(since: start)
                    )
                    cache(context.commandID, result: forwarded)
                    return forwarded
                }

                let position = enqueueDeferred(
                    DeferredExecutionAction(
                        action: action,
                        context: context,
                        queuedAt: Date()
                    )
                )
                let queued = RoutedExecutionResult(
                    status: .queued,
                    detail: "Queued until receiver returns to foreground",
                    executor: .iosReceiver,
                    queuePosition: position,
                    errorCode: relay.errorCode ?? "queued_foreground_required",
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: queued)
                return queued

            case .queue:
                let position = enqueueDeferred(
                    DeferredExecutionAction(
                        action: action,
                        context: context,
                        queuedAt: Date()
                    )
                )
                let queued = RoutedExecutionResult(
                    status: .queued,
                    detail: "Queued until receiver returns to foreground",
                    executor: .iosReceiver,
                    queuePosition: position,
                    errorCode: "queued_foreground_required",
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: queued)
                return queued

            case .fail:
                let failed = RoutedExecutionResult(
                    status: .failed,
                    detail: "Action needs receiver app in foreground",
                    executor: .iosReceiver,
                    queuePosition: nil,
                    errorCode: "foreground_required",
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: failed)
                return failed
            }
        }

        let local = await executeLocal(action)
        if local.isSuccess {
            let success = RoutedExecutionResult(
                status: .success,
                detail: local.displayText,
                executor: .iosReceiver,
                queuePosition: nil,
                errorCode: nil,
                latencyMs: elapsedMS(since: start)
            )
            cache(context.commandID, result: success)
            return success
        }

        if context.fallbackPolicy == .relay {
            let relay = await tryRelay(
                action: action,
                sourceDeviceName: sourceDeviceName,
                reason: "receiver_local_execution_failed",
                traceID: context.traceID,
                attempt: context.attempt,
                ttlSeconds: context.ttlSeconds
            )
            if relay.success {
                let forwarded = RoutedExecutionResult(
                    status: .forwarded,
                    detail: relay.detail ?? "Executed via Mac relay",
                    executor: .macRelay,
                    queuePosition: nil,
                    errorCode: nil,
                    latencyMs: elapsedMS(since: start)
                )
                cache(context.commandID, result: forwarded)
                return forwarded
            }
        }

        let failed = RoutedExecutionResult(
            status: .failed,
            detail: local.displayText,
            executor: .iosReceiver,
            queuePosition: nil,
            errorCode: "local_execution_failed",
            latencyMs: elapsedMS(since: start)
        )
        cache(context.commandID, result: failed)
        return failed
    }

    func routeDeferred(
        deferred: DeferredExecutionAction,
        sourceDeviceName: String,
        executeLocal: @escaping @MainActor (ButtonAction) async -> ExecutionResult
    ) async -> RoutedExecutionResult {
        let start = Date()
        let local = await executeLocal(deferred.action)
        if local.isSuccess {
            let success = RoutedExecutionResult(
                status: .success,
                detail: local.displayText,
                executor: .iosReceiver,
                queuePosition: nil,
                errorCode: nil,
                latencyMs: elapsedMS(since: start)
            )
            cache(deferred.context.commandID, result: success)
            return success
        }

        if deferred.context.fallbackPolicy == .relay {
            let relay = await tryRelay(
                action: deferred.action,
                sourceDeviceName: sourceDeviceName,
                reason: "deferred_execution_local_failed",
                traceID: deferred.context.traceID,
                attempt: deferred.context.attempt,
                ttlSeconds: deferred.context.ttlSeconds
            )
            if relay.success {
                let forwarded = RoutedExecutionResult(
                    status: .forwarded,
                    detail: relay.detail ?? "Executed via Mac relay",
                    executor: .macRelay,
                    queuePosition: nil,
                    errorCode: nil,
                    latencyMs: elapsedMS(since: start)
                )
                cache(deferred.context.commandID, result: forwarded)
                return forwarded
            }
        }

        let failed = RoutedExecutionResult(
            status: .failed,
            detail: local.displayText,
            executor: .iosReceiver,
            queuePosition: nil,
            errorCode: "deferred_local_failed",
            latencyMs: elapsedMS(since: start)
        )
        cache(deferred.context.commandID, result: failed)
        return failed
    }

    private func cache(_ commandID: UUID, result: RoutedExecutionResult) {
        if dedupCache.count >= dedupMaxEntries {
            dedupCache = dedupCache
                .sorted { $0.value.expiresAt > $1.value.expiresAt }
                .prefix(dedupMaxEntries / 2)
                .reduce(into: [:]) { $0[$1.key] = $1.value }
        }
        dedupCache[commandID] = DedupRecord(
            result: result,
            expiresAt: Date().addingTimeInterval(dedupTTLSeconds)
        )
    }

    private func pruneDedupCache() {
        let now = Date()
        dedupCache = dedupCache.filter { $0.value.expiresAt > now }
    }

    private func elapsedMS(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func tryRelay(
        action: ButtonAction,
        sourceDeviceName: String,
        reason: String,
        traceID: String,
        attempt: Int,
        ttlSeconds: Int?
    ) async -> RelayForwardResult {
        await BackgroundCommandRelayService.shared.forward(
            action: action,
            sourceDeviceName: sourceDeviceName,
            reason: reason,
            traceID: traceID,
            idempotencyKey: "\(traceID):\(attempt)",
            attempt: attempt,
            ttlSeconds: ttlSeconds
        )
    }
}
