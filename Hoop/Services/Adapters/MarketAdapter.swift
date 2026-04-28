// Hoop/Services/Adapters/MarketAdapter.swift
import Foundation

protocol MarketAdapter: AnyObject {
    var id: String { get }
    var name: String { get }
    var connectionType: ConnectionType { get }
    @MainActor var connectionState: AdapterConnectionState { get }

    func connect() async throws
    func disconnect()

    var signalStream: AsyncStream<RawSignal> { get }
}
