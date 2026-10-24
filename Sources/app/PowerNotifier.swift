// PowerNotifier.swift — 高功耗本地通知（SPEC F9）
// 触发口径与兽喘气态同源（F1 滞回判定成立才进来，不追瞬时尖峰）；
// 10 分钟冷却防轰炸；面板开关持久化在 UserDefaults（默认开）；授权被拒则静默停用。

import Foundation
import UserNotifications

@MainActor
final class PowerNotifier {
    private static let toggleKey = "HighPowerNotifyEnabled"
    private static let identifier = "highpower"
    private let center = UNUserNotificationCenter.current()
    private var lastFire: Date?
    private let cooldown: TimeInterval = 600

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.toggleKey) as? Bool ?? true
    }

    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.toggleKey)
        if on { requestAuthorization() }
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert]) { _, _ in
            // 授权结果不落地缓存：每次通知前实时查询系统状态（settings 检查），
            // 用户事后在系统设置里打开授权无需重启 app 即生效
            NSLog("powermon: 通知授权请求回调（结果以 getNotificationSettings 实时查询为准）")
        }
    }

    /// 进入喘气态时调用。开关关闭 / 未授权 / 冷却期内均静默跳过。
    func notifyHighPower(watts: Int, feeder: String) {
        guard isEnabled else { return }
        if let last = lastFire, Date().timeIntervalSince(last) < cooldown { return }

        // 实时查授权状态（含临时授权/专注模式等系统态），不信任启动时的缓存
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self, self.isEnabled else { return }
                guard settings.authorizationStatus == .authorized else {
                    NSLog("powermon: 通知未授权（status=%d），跳过；可到系统设置→通知→PowerMon 打开",
                          settings.authorizationStatus.rawValue)
                    return
                }
                // 评审 B1：投递成功才算冷却起点，避免"授权前的一次尝试"吞掉授权后的第一条通知
                self.lastFire = Date()
                let content = UNMutableNotificationContent()
                content.title = "耗电兽报警"
                content.body = "持续高功耗 \(watts)W · \(feeder) 在添柴"
                let req = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
                self.center.add(req) { err in
                    NSLog(err == nil ? "powermon: 高功耗通知已投递" : "powermon: 通知投递失败 \(err!)")
                }
            }
        }
    }
}
