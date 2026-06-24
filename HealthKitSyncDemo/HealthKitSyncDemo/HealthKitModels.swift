//
//  HealthKitModels.swift
//  HealthKitSyncDemo
//
//  这个文件只放数据结构：Swift 端读取到的数据，以及 POST 给 Python 后端的 JSON 形状。
//

import Foundation

// HeartRateSamplePayload 对应 Python 后端里的 latestHeartRate 字段。
struct HeartRateSamplePayload: Codable, Equatable {
    // bpm 是 beats per minute，也就是每分钟心跳次数。
    let bpm: Double

    // measuredAt 是 HealthKit 记录这条心率数据的时间，格式是 ISO 8601 字符串。
    let measuredAt: String
}

// HealthKitSyncPayload 是 Swift 发给 Python 后端的完整 JSON body。
struct HealthKitSyncPayload: Codable, Equatable {
    // source 用来标记这条数据来自哪个 demo 客户端。
    let source: String

    // syncedAt 是 App 点击同步并组装 payload 的时间，格式是 ISO 8601 字符串。
    let syncedAt: String

    // date 是今天的本地日期，格式是 yyyy-MM-dd，对应 Python 后端的 date 字段。
    let date: String

    // steps 是今天累计步数；用户未授权或没有数据时可以为空。
    let steps: Int?

    // activeEnergyKcal 是今天累计活动能量，单位是千卡；用户未授权或没有数据时可以为空。
    let activeEnergyKcal: Double?

    // latestHeartRate 是最近一条心率样本；用户未授权或没有数据时可以为空。
    let latestHeartRate: HeartRateSamplePayload?

    // stepsText 给 UI 展示用，避免 ContentView 关心 nil 怎么显示。
    var stepsText: String {
        // 如果 steps 有值就显示整数，否则显示暂无数据。
        if let steps {
            return "\(steps)"
        }

        // nil 表示 HealthKit 没有返回这项数据。
        return "暂无数据"
    }

    // activeEnergyText 给 UI 展示活动能量。
    var activeEnergyText: String {
        // 如果有活动能量，就保留一位小数并追加单位。
        if let activeEnergyKcal {
            return String(format: "%.1f kcal", activeEnergyKcal)
        }

        // nil 表示 HealthKit 没有返回这项数据。
        return "暂无数据"
    }

    // heartRateText 给 UI 展示最近心率。
    var heartRateText: String {
        // 如果有最近心率，就保留整数展示 bpm。
        if let latestHeartRate {
            return String(format: "%.0f bpm", latestHeartRate.bpm)
        }

        // nil 表示没有心率样本或用户没有授权。
        return "暂无数据"
    }
}

// HealthKitSyncResponse 对应 Python 后端 POST 成功后的响应 JSON。
struct HealthKitSyncResponse: Decodable, Equatable {
    // ok 表示后端是否成功处理。
    let ok: Bool

    // message 是后端返回的简短消息。
    let message: String

    // savedPath 是 Python 后端保存 jsonl 的本地路径。
    let savedPath: String
}

// HealthKitPayloadDateFormatter 集中处理日期格式，避免散落在多个文件里。
enum HealthKitPayloadDateFormatter {
    // isoFormatter 用来生成 syncedAt 和 measuredAt。
    private static let isoFormatter: ISO8601DateFormatter = {
        // ISO8601DateFormatter 输出类似 2026-06-23T08:00:00Z。
        let formatter = ISO8601DateFormatter()

        // withInternetDateTime 是后端最容易解析的标准时间格式。
        formatter.formatOptions = [.withInternetDateTime]

        // 返回配置好的 formatter。
        return formatter
    }()

    // dayFormatter 用来生成 yyyy-MM-dd 的本地日期。
    private static let dayFormatter: DateFormatter = {
        // DateFormatter 负责把 Date 转成只包含日期的字符串。
        let formatter = DateFormatter()

        // en_US_POSIX 能避免设备语言影响日期格式。
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // 当前时区表示“今天”按照用户手机所在时区计算。
        formatter.timeZone = .current

        // yyyy-MM-dd 正好对应 Python 后端的 date 字段。
        formatter.dateFormat = "yyyy-MM-dd"

        // 返回配置好的 formatter。
        return formatter
    }()

    // isoString 把 Date 转成 ISO 8601 字符串。
    static func isoString(from date: Date) -> String {
        // 统一用同一个 formatter，保证所有时间字段格式一致。
        isoFormatter.string(from: date)
    }

    // dayString 把 Date 转成 yyyy-MM-dd 字符串。
    static func dayString(from date: Date) -> String {
        // 统一用同一个 formatter，保证 date 字段只包含日期。
        dayFormatter.string(from: date)
    }
}
