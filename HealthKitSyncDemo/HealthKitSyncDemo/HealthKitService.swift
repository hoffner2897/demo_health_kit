//
//  HealthKitService.swift
//  HealthKitSyncDemo
//
//  这个文件只负责和 Apple HealthKit 交互：检查可用性、请求权限、读取三类数据。
//

import Foundation
import HealthKit

// HealthKitServiceError 表示 HealthKit 读取过程中可能遇到的业务错误。
enum HealthKitServiceError: LocalizedError {
    // healthDataUnavailable 表示当前设备不支持 HealthKit，例如部分 iPad 或模拟器场景。
    case healthDataUnavailable

    // quantityTypeUnavailable 表示系统没有返回某个 HealthKit quantity type。
    case quantityTypeUnavailable(HKQuantityTypeIdentifier)

    // errorDescription 会显示给用户看。
    var errorDescription: String? {
        // 根据不同错误返回中文说明。
        switch self {
        case .healthDataUnavailable:
            return "当前设备不支持 HealthKit，请用支持健康数据的 iPhone 真机测试。"
        case .quantityTypeUnavailable(let identifier):
            return "HealthKit 数据类型不可用：\(identifier.rawValue)"
        }
    }
}

// HealthKitService 是读取 HealthKit 的唯一入口。
final class HealthKitService {
    // healthStore 是 Apple 提供的 HealthKit 数据访问对象。
    private let healthStore = HKHealthStore()

    // readTodayPayload 是给 ViewModel 调用的主方法：授权并读取今天的数据。
    func readTodayPayload() async throws -> HealthKitSyncPayload {
        // HealthKit 只能在支持健康数据的设备上使用。
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        // 先请求读取权限；用户第一次运行时会看到系统权限弹窗。
        try await requestReadAuthorization()

        // now 是本次同步的时间点。
        let now = Date()

        // calendar 用来计算今天从几点开始。
        let calendar = Calendar.current

        // startOfDay 是今天 00:00，步数和活动能量都按今天累计。
        let startOfDay = calendar.startOfDay(for: now)

        // stepsDouble 是 HealthKit 返回的步数原始 Double。
        let stepsDouble = try await cumulativeQuantity(
            for: .stepCount,
            unit: .count(),
            from: startOfDay,
            to: now
        )

        // activeEnergyKcal 是 HealthKit 返回的活动能量，单位是 kcal。
        let activeEnergyKcal = try await cumulativeQuantity(
            for: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: startOfDay,
            to: now
        )

        // latestHeartRate 是最近一条心率样本。
        let latestHeartRate = try await latestHeartRateSample()

        // payload 是最终会 POST 给 Python 后端的 JSON 数据结构。
        return HealthKitSyncPayload(
            source: "ios-healthkit-demo",
            syncedAt: HealthKitPayloadDateFormatter.isoString(from: now),
            date: HealthKitPayloadDateFormatter.dayString(from: now),
            steps: stepsDouble.map { Int($0.rounded()) },
            activeEnergyKcal: activeEnergyKcal,
            latestHeartRate: latestHeartRate
        )
    }

    // requestReadAuthorization 请求读取步数、活动能量和心率的权限。
    private func requestReadAuthorization() async throws {
        // readTypes 收集本 demo 需要读取的 HealthKit 数据类型。
        let readTypes = try Set<HKObjectType>([
            quantityType(for: .stepCount),
            quantityType(for: .activeEnergyBurned),
            quantityType(for: .heartRate)
        ])

        // HealthKit 的授权 API 是回调形式，这里包装成 async/await。
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // toShare 为空数组，表示本 demo 不写入 HealthKit，只读取。
            healthStore.requestAuthorization(toShare: [], read: readTypes) { _, error in
                // 如果系统返回 error，就把错误交给调用方。
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                // 注意：success 只代表授权流程结束，不代表用户同意了每一项数据。
                continuation.resume()
            }
        }
    }

    // cumulativeQuantity 读取某个 quantity type 在一个时间段里的累计值。
    private func cumulativeQuantity(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        // quantityType 是 HealthKit 中具体的数据类型，例如 stepCount。
        let quantityType = try quantityType(for: identifier)

        // predicate 限定只读取今天 00:00 到当前时间之间的数据。
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // HKStatisticsQuery 是读取累计数据的标准方式，例如今天总步数。
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            // query 描述本次 HealthKit 统计查询。
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                // 如果 HealthKit 查询失败，直接返回错误。
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                // sumQuantity 是这段时间的累计值；没有数据时为 nil。
                let value = statistics?
                    .sumQuantity()?
                    .doubleValue(for: unit)

                // 把累计值返回给 async 调用方。
                continuation.resume(returning: value)
            }

            // execute 真正把查询交给 HealthKit 执行。
            healthStore.execute(query)
        }
    }

    // latestHeartRateSample 读取最近一条心率样本。
    private func latestHeartRateSample() async throws -> HeartRateSamplePayload? {
        // sampleType 表示要读取 heartRate 类型的样本。
        let sampleType = try quantityType(for: .heartRate)

        // sortDescriptor 让最新的数据排在最前面。
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        // HKSampleQuery 适合读取原始样本，例如最近一次心率。
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HeartRateSamplePayload?, Error>) in
            // query 限制只取 1 条最新 heartRate 样本。
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                // 如果 HealthKit 查询失败，直接返回错误。
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                // firstSample 是最近一条心率样本。
                guard let firstSample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                // bpmUnit 表示 count/min，也就是每分钟心跳次数。
                let bpmUnit = HKUnit.count().unitDivided(by: .minute())

                // bpm 是具体的心率数值。
                let bpm = firstSample.quantity.doubleValue(for: bpmUnit)

                // measuredAt 使用样本结束时间作为记录时间。
                let measuredAt = HealthKitPayloadDateFormatter.isoString(from: firstSample.endDate)

                // 把心率样本转换成后端需要的 JSON 子结构。
                let payload = HeartRateSamplePayload(
                    bpm: bpm,
                    measuredAt: measuredAt
                )

                // 返回最近心率。
                continuation.resume(returning: payload)
            }

            // execute 真正把查询交给 HealthKit 执行。
            healthStore.execute(query)
        }
    }

    // quantityType 把 HKQuantityTypeIdentifier 转成 HKQuantityType，并统一处理 nil。
    private func quantityType(for identifier: HKQuantityTypeIdentifier) throws -> HKQuantityType {
        // Apple API 这里返回 optional，所以需要显式兜底。
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.quantityTypeUnavailable(identifier)
        }

        // 返回可以用于查询或授权的数据类型。
        return type
    }
}
