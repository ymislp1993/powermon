// PowerMonApp.swift — 菜单栏 app 入口（v1.0，规格见 docs/SPEC.md）
// LSUIElement 由 Info.plist 声明：不占 Dock，仅菜单栏常驻

import SwiftUI
import ServiceManagement
import UserNotifications

@main
struct PowerMonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    // 刻意不用 @StateObject 订阅整个 store（P1）：Scene 层不随面板数据发布失效，
    // 菜单栏重算只由 MenuBarLabel 内的 MenuIconStore 发布驱动
    private let store = PowerStore.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuBarLabel(menu: store.menu)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏 label：独立 View + @ObservedObject，只订阅 MenuIconStore（petState/isHot），
/// 与温度/台词等面板发布完全解耦（P1）
private struct MenuBarLabel: View {
    @ObservedObject var menu: MenuIconStore

    var body: some View {
        // 耗电兽状态图标（单色模板渲染），异常时追加 "!"
        HStack(spacing: 1) {
            Image(systemName: menu.petState.symbolName)
            if menu.isHot { Text("!") }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PowerStore.shared.start()
        // 评审 B2 自愈：SMAppService 注册绑定路径——若存在指向旧路径的注册
        // （如从 build/ 开过自启后 make install 搬家），重注册一次改指当前 bundle
        let status = SMAppService.mainApp.status
        if status == .enabled || status == .requiresApproval {
            try? SMAppService.mainApp.register()
        }
        // F9：启动即请求通知授权（一次）；被拒则高功耗通知静默停用
        UNUserNotificationCenter.current().delegate = self
        PowerStore.shared.notifier.requestAuthorization()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // terminate 流程不等待异步任务，清理必须同步执行（评审 B5）
        MainActor.assumeIsolated {
            PowerStore.shared.stopSampling()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// LSUIElement app 一般不在前台，但保险起见前台也以横幅呈现
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
