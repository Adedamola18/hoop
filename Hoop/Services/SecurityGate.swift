// Hoop/Services/SecurityGate.swift
import AppKit
import Foundation
import Observation
import Security
import CryptoKit

@Observable
final class SecurityGate {

    enum AuthPhase {
        case idle
        case scanning
        case success
        case failure(attemptsRemaining: Int)
        case lockedOut(until: Date)
    }

    private(set) var authPhase: AuthPhase = .idle
    private(set) var isUnlocked: Bool = false
    private(set) var isPINConfigured: Bool = false

    var protectedWidgetIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "protectedWidgetIds") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "protectedWidgetIds")
        }
    }

    var autoLockTimeoutMinutes: Int {
        UserDefaults.standard.object(forKey: "autoLockTimeout") as? Int ?? 5
    }

    var lockOnSleep: Bool {
        UserDefaults.standard.object(forKey: "lockOnSleep") as? Bool ?? true
    }

    private var failedAttempts = 0
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 30
    private var autoLockTimer: Timer?
    private var lockoutTimer: Timer?
    private var sleepObserver: Any?

    private let keychainService = "com.hoops.hoop.securitygate"
    private let keychainAccount = "pin-hash"
    private let pinConfiguredFlagKey = "hasPINConfigured"
    private let migrationFlagKey = "securityGateMigratedV2"

    var onLockStateChanged: (() -> Void)?

    // MARK: - Lifecycle

    func startObserving() {
        // Avoid probing the Keychain at launch — that triggers the macOS account-password
        // prompt every time the app's code signature changes (every Debug rebuild).
        // Instead, mirror the configured state in UserDefaults and only touch the Keychain
        // during PIN setup or unlock attempts.
        if UserDefaults.standard.bool(forKey: migrationFlagKey) {
            isPINConfigured = UserDefaults.standard.bool(forKey: pinConfiguredFlagKey)
        } else {
            // The Keychain service ID changed during the NotchNook → Hoop rename, so
            // any previously stored PIN now lives under an orphaned service. Reset
            // the configured-state and mark the migration done; the user can set up a
            // new PIN from Settings if they want one.
            UserDefaults.standard.set(false, forKey: pinConfiguredFlagKey)
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            isPINConfigured = false
        }

        // Default-protect trading alerts widget on first setup
        if isPINConfigured && !UserDefaults.standard.bool(forKey: "securityDefaultsApplied") {
            var ids = protectedWidgetIds
            ids.insert("tradingAlerts")
            protectedWidgetIds = ids
            UserDefaults.standard.set(true, forKey: "securityDefaultsApplied")
        }

        if lockOnSleep {
            sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.lock()
            }
        }
    }

    func stopObserving() {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }
    }

    // MARK: - Lock/Unlock

    func isProtected(_ widgetId: String) -> Bool {
        isPINConfigured && protectedWidgetIds.contains(widgetId)
    }

    func lock() {
        isUnlocked = false
        authPhase = .idle
        autoLockTimer?.invalidate()
        autoLockTimer = nil
        onLockStateChanged?()
    }

    func attemptUnlock(pin: String) -> Bool {
        guard isPINConfigured else { return false }

        if case .lockedOut(let until) = authPhase {
            if Date() < until { return false }
            failedAttempts = 0
        }

        authPhase = .scanning

        let inputHash = hashPIN(pin)
        guard let storedHash = loadPINHash(), inputHash == storedHash else {
            failedAttempts += 1
            let remaining = maxAttempts - failedAttempts
            if remaining <= 0 {
                let lockoutEnd = Date().addingTimeInterval(lockoutDuration)
                authPhase = .lockedOut(until: lockoutEnd)
                lockoutTimer = Timer.scheduledTimer(withTimeInterval: lockoutDuration, repeats: false) { [weak self] _ in
                    self?.failedAttempts = 0
                    self?.authPhase = .idle
                }
            } else {
                authPhase = .failure(attemptsRemaining: remaining)
            }
            return false
        }

        // Success
        authPhase = .success
        isUnlocked = true
        failedAttempts = 0
        resetAutoLockTimer()
        onLockStateChanged?()
        return true
    }

    func resetAutoLockTimer() {
        autoLockTimer?.invalidate()
        let timeout = autoLockTimeoutMinutes
        guard timeout > 0 else { return } // 0 = never
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout * 60), repeats: false) { [weak self] _ in
            self?.lock()
        }
    }

    // MARK: - PIN Management

    func setupPIN(_ pin: String) -> Bool {
        let hash = hashPIN(pin)
        let saved = savePINHash(hash)
        if saved {
            isPINConfigured = true
            UserDefaults.standard.set(true, forKey: pinConfiguredFlagKey)
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            var ids = protectedWidgetIds
            ids.insert("tradingAlerts")
            protectedWidgetIds = ids
            UserDefaults.standard.set(true, forKey: "securityDefaultsApplied")
        }
        return saved
    }

    func changePIN(currentPIN: String, newPIN: String) -> Bool {
        let currentHash = hashPIN(currentPIN)
        guard let storedHash = loadPINHash(), currentHash == storedHash else {
            return false
        }
        deletePINHash()
        return setupPIN(newPIN)
    }

    // MARK: - Keychain

    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func savePINHash(_ hash: String) -> Bool {
        deletePINHash()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: Data(hash.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func loadPINHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deletePINHash() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
