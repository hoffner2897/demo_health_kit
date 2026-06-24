//
//  HealthSyncViewModel.swift
//  HealthKitSyncDemo
//
//  这个文件负责串联流程：页面点击按钮后，先读 HealthKit，再上传到 Python 后端。
//

import Combine
import Foundation

// HealthSyncViewModel 是 ContentView 和底层服务之间的桥。
@MainActor
final class HealthSyncViewModel: ObservableObject {
    // isSyncing 控制按钮是否显示 loading，以及是否禁用重复点击。
    @Published private(set) var isSyncing = false

    // statusTitle 是页面上的状态标题。
    @Published private(set) var statusTitle = "准备同步"

    // statusDetail 是页面上的状态详情。
    @Published private(set) var statusDetail = "点击按钮后，会请求 HealthKit 权限并上传到 Python 后端。"

    // latestPayload 保存最近一次从 HealthKit 读到并准备上传的数据。
    @Published private(set) var latestPayload: HealthKitSyncPayload?

    // healthKitService 专门负责 HealthKit 授权和读取。
    private let healthKitService: HealthKitService

    // backendClient 专门负责 POST 到 Python 后端。
    private let backendClient: BackendClient

    // init 创建 ViewModel 依赖的两个服务；参数可选是为了避免默认参数触发 MainActor 初始化 warning。
    init(
        healthKitService: HealthKitService? = nil,
        backendClient: BackendClient? = nil
    ) {
        // 保存 HealthKit 服务；没有注入时就创建默认实现。
        self.healthKitService = healthKitService ?? HealthKitService()

        // 保存后端客户端；没有注入时就创建默认实现。
        self.backendClient = backendClient ?? BackendClient()
    }

    // sync 是 ContentView 按钮点击时调用的方法。
    func sync() {
        // 如果已经在同步，就直接返回，避免重复请求权限或重复 POST。
        guard !isSyncing else {
            return
        }

        // Task 让按钮点击后可以执行 async/await 流程。
        Task {
            // runSync 执行真正的读取和上传。
            await runSync()
        }
    }

    // runSync 执行完整同步流程。
    private func runSync() async {
        // 标记进入同步中状态。
        isSyncing = true

        // 同步结束时一定恢复按钮可点击。
        defer {
            isSyncing = false
        }

        // 更新 UI，提示用户正在请求或读取 HealthKit。
        statusTitle = "正在读取 HealthKit"
        statusDetail = "如果是第一次运行，系统会弹出健康数据权限请求。"

        do {
            // 从 HealthKit 读取今天步数、活动能量和最近心率。
            let payload = try await healthKitService.readTodayPayload()

            // 保存 payload，让页面可以展示最近一次读取结果。
            latestPayload = payload

            // 更新 UI，提示用户正在上传到 Python 后端。
            statusTitle = "正在上传后端"
            statusDetail = "正在 POST 到 Python FastAPI 的 /healthkit/sync。"

            // 把 payload 发送到 Python 后端。
            let response = try await backendClient.upload(payload)

            // 上传成功后展示后端返回的信息。
            statusTitle = response.ok ? "同步成功" : "后端未确认"
            statusDetail = "后端消息：\(response.message)，保存路径：\(response.savedPath)"
        } catch {
            // 任意一步失败都会进入这里，包括 HealthKit 权限、读取、网络、后端错误。
            statusTitle = "同步失败"

            // localizedDescription 会优先使用我们在 Error 里写的中文说明。
            statusDetail = error.localizedDescription
        }
    }
}
