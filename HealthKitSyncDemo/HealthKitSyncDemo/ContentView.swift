//
//  ContentView.swift
//  HealthKitSyncDemo
//
//  这个文件只负责页面展示：按钮、同步状态、最近一次读取到的数据。
//

import SwiftUI

// ContentView 是 App 的主页面。
struct ContentView: View {
    // ViewModel 保存页面状态，并负责触发完整同步流程。
    @StateObject private var viewModel = HealthSyncViewModel()

    // body 描述这个页面长什么样。
    var body: some View {
        // NavigationStack 给页面一个标准 iOS 导航容器。
        NavigationStack {
            // ScrollView 避免小屏幕上内容被挤出屏幕。
            ScrollView {
                // VStack 让页面内容从上到下排列。
                VStack(alignment: .leading, spacing: 24) {
                    // 顶部说明区域告诉测试者这个 demo 当前只做按钮同步。
                    headerSection

                    // 同步按钮区域负责触发 HealthKit 读取和后端上传。
                    syncButtonSection

                    // 状态区域展示 loading、成功或失败信息。
                    statusSection

                    // 如果已经读到过 HealthKit 数据，就展示最近一次 payload 摘要。
                    payloadSection
                }
                // 页面边缘留白，让内容不要贴边。
                .padding(24)
            }
            // 导航标题显示在 Xcode 运行出来的 App 顶部。
            .navigationTitle("HealthKit Sync")
        }
    }

    // headerSection 是页面顶部的简短目标说明。
    private var headerSection: some View {
        // VStack 让标题和说明文字纵向排列。
        VStack(alignment: .leading, spacing: 8) {
            // 标题强调这个 demo 的唯一目标。
            Text("按钮触发同步")
                .font(.title)
                .fontWeight(.semibold)

            // 说明文字避免把范围扩散到登录、OCR、推荐或后台同步。
            Text("读取今天步数、活动能量、最近心率，并发送到本地 Python 后端。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // syncButtonSection 是实际操作入口。
    private var syncButtonSection: some View {
        // Button 点击后调用 ViewModel 的 sync()。
        Button {
            // sync() 内部会启动异步任务，所以这里不需要 await。
            viewModel.sync()
        } label: {
            // HStack 让图标和文字横向排列。
            HStack(spacing: 10) {
                // 同步中显示 ProgressView，空闲时显示系统同步图标。
                if viewModel.isSyncing {
                    // ProgressView 表示当前正在读取或上传。
                    ProgressView()
                        .tint(.white)
                } else {
                    // SF Symbol 图标让按钮含义更直观。
                    Image(systemName: "arrow.triangle.2.circlepath")
                }

                // 按钮文字会根据同步状态切换。
                Text(viewModel.isSyncing ? "同步中..." : "同步 HealthKit 数据")
                    .fontWeight(.medium)
            }
            // 让按钮内容撑满横向空间。
            .frame(maxWidth: .infinity)
            // 固定按钮高度，避免 loading 状态导致布局跳动。
            .frame(height: 52)
        }
        // borderedProminent 是系统主按钮样式。
        .buttonStyle(.borderedProminent)
        // 同步中禁用按钮，避免重复 POST。
        .disabled(viewModel.isSyncing)
    }

    // statusSection 显示当前流程状态。
    private var statusSection: some View {
        // VStack 让状态标题和详情分两行显示。
        VStack(alignment: .leading, spacing: 8) {
            // 状态标题，例如“准备同步”“同步成功”“同步失败”。
            Text(viewModel.statusTitle)
                .font(.headline)

            // 状态详情通常是下一步提示、后端返回或错误信息。
            Text(viewModel.statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        // 状态区域占满宽度，保持页面稳定。
        .frame(maxWidth: .infinity, alignment: .leading)
        // 使用系统背景色形成轻量信息区。
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // payloadSection 展示最近一次发给 Python 后端的数据摘要。
    @ViewBuilder
    private var payloadSection: some View {
        // 只有同步成功或读取完成后才会有 latestPayload。
        if let payload = viewModel.latestPayload {
            // VStack 让小标题和数据行纵向排列。
            VStack(alignment: .leading, spacing: 12) {
                // 小标题说明下面是最近一次 payload。
                Text("最近一次读取")
                    .font(.headline)

                // 每一行展示 payload 中的一个字段。
                metricRow(title: "日期", value: payload.date)
                metricRow(title: "步数", value: payload.stepsText)
                metricRow(title: "活动能量", value: payload.activeEnergyText)
                metricRow(title: "最近心率", value: payload.heartRateText)
                metricRow(title: "同步时间", value: payload.syncedAt)
            }
            // 数据区占满宽度，便于阅读。
            .frame(maxWidth: .infinity, alignment: .leading)
            // 数据区使用轻量背景，与状态区一致。
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // metricRow 统一渲染一行 key/value 数据。
    private func metricRow(title: String, value: String) -> some View {
        // HStack 让字段名和值分布在左右两侧。
        HStack(alignment: .firstTextBaseline) {
            // 字段名使用次级颜色，减少视觉噪音。
            Text(title)
                .foregroundStyle(.secondary)

            // Spacer 把值推到右侧。
            Spacer(minLength: 16)

            // 字段值允许选择，方便 debug 时复制。
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        // callout 比正文略小，适合列表型数据。
        .font(.callout)
    }
}
