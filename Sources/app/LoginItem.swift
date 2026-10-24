// LoginItem.swift — 登录自启（SPEC F10，macOS 13+ SMAppService）
// 面板开关直接读写 mainApp 的注册状态；app 需处于最终安装位置（/Applications）体验最佳

import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                // requiresApproval（系统设置里被关掉的 pending 注册）也要注销干净（评审 B1）
                let status = SMAppService.mainApp.status
                guard status == .enabled || status == .requiresApproval else { return }
                try SMAppService.mainApp.unregister()
            }
            NSLog("powermon: 登录自启已%@", on ? "开启" : "关闭")
        } catch {
            NSLog("powermon: 登录自启设置失败 \(error)")
        }
    }
}
