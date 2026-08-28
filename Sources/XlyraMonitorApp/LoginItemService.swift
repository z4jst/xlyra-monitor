import Foundation
import ServiceManagement

protocol LoginItemManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

enum LoginItemError: Error {
    case updateFailed
}

extension LoginItemManaging {
    func applyEnabledState(_ isEnabled: Bool) throws {
        try setEnabled(isEnabled)
        guard self.isEnabled == isEnabled else {
            throw LoginItemError.updateFailed
        }
    }
}

struct LoginItemService: LoginItemManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        do {
            let status = SMAppService.mainApp.status
            if isEnabled {
                if status == .notRegistered {
                    try SMAppService.mainApp.register()
                }
            } else if status == .enabled || status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LoginItemError.updateFailed
        }
    }
}
