import Charts
import Foundation
import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ExerciseProgressView: View {
    let detail: ExerciseDetailModel.Detail
    let locale: AppLocale
    let cacheKey: String
    let animationLoader: @Sendable () async throws -> Data

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                ExerciseProgressOverview(detail: detail, locale: locale)
                ExerciseTaxonomy(exercise: detail.exercise)

                ExerciseDemonstration(
                    cacheKey: cacheKey,
                    hasAnimation: detail.exercise.hasAnimation,
                    load: animationLoader
                )

                if let description = detail.exercise.description, !description.isEmpty {
                    Text(description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !detail.exercise.instructions.isEmpty {
                    ExerciseInstructions(steps: detail.exercise.instructions)
                }

                if detail.datedHistorySessions.count > 1 {
                    ExerciseWeightChart(detail: detail, locale: locale)
                }

                ExerciseHistoryList(detail: detail, locale: locale)
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private struct ExerciseProgressOverview: View {
    let detail: ExerciseDetailModel.Detail
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Label("Exercise progress", systemImage: "chart.xyaxis.line")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                Text(detail.exercise.name)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let bestWeight = detail.bestWeight {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: LacticSpacing.xl) { metrics(bestWeight: bestWeight) }
                    VStack(alignment: .leading, spacing: LacticSpacing.md) { metrics(bestWeight: bestWeight) }
                }

                if let change = detail.bestWeightChange {
                    Label(changeText(change), systemImage: change >= .zero ? "arrow.up.right" : "arrow.down.right")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(change >= .zero ? LacticColor.brand : LacticColor.textOnHero)
                }
            } else {
                Text("Log this exercise to start tracking your progress.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }

    @ViewBuilder
    private func metrics(bestWeight: Decimal) -> some View {
        ProgressMetric(
            value: "\(Formatters.weight(bestWeight, locale: locale)) kg",
            label: String(localized: "Best weight")
        )
        ProgressMetric(
            value: detail.historySessions.count.formatted(),
            label: String(localized: "Sessions")
        )
        ProgressMetric(
            value: detail.totalReps.formatted(),
            label: String(localized: "Total reps")
        )
    }

    private func changeText(_ change: Decimal) -> String {
        let value = Formatters.weight(abs(change), locale: locale)
        if change > .zero {
            return String(localized: "+\(value) kg since first session")
        }
        if change < .zero {
            return String(localized: "−\(value) kg since first session")
        }
        return String(localized: "Level with your first session")
    }
}

private struct ProgressMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            Text(value)
                .font(.lacticNumeric)
                .foregroundStyle(LacticColor.brand)
            Text(label)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textOnHero)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseTaxonomy: View {
    let exercise: ExerciseDetail

    var body: some View {
        FlowLayout(spacing: LacticSpacing.xs) {
            if let primary = exercise.primaryMuscle {
                StatusBadge(primary.name, tone: .informative)
            }
            ForEach(exercise.secondaryMuscles, id: \.key) { muscle in
                StatusBadge(muscle.name)
            }
            ForEach(exercise.equipment, id: \.key) { item in
                StatusBadge(item.name)
            }
        }
    }
}

private struct ExerciseInstructions: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("How to do it")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: LacticSpacing.sm) {
                    Text("\(index + 1).")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textMuted)
                    Text(step)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                }
            }
        }
        .padding(LacticSpacing.lg)
        .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}

private struct ExerciseWeightChart: View {
    let detail: ExerciseDetailModel.Detail
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text("Best weight trend")
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                Text("Your heaviest set in each session")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }

            Chart(detail.datedHistorySessions) { session in
                if let performedAt = session.performedAt {
                    LineMark(
                        x: .value("Date", performedAt),
                        y: .value("Weight", decimalValue(session.bestWeight))
                    )
                    .foregroundStyle(LacticColor.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Date", performedAt),
                        y: .value("Weight", decimalValue(session.bestWeight))
                    )
                    .foregroundStyle(LacticColor.accent)
                    .symbolSize(60)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(LacticColor.border)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(LacticColor.border)
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text(weight, format: .number.precision(.fractionLength(0 ... 1)))
                        }
                    }
                }
            }
            .aspectRatio(1.65, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best weight trend")
            .accessibilityValue(chartSummary)
        }
        .padding(LacticSpacing.lg)
        .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }

    private var chartSummary: String {
        guard let first = detail.datedHistorySessions.first,
              let last = detail.datedHistorySessions.last
        else { return String(localized: "No progress data") }
        let firstWeight = Formatters.weight(first.bestWeight, locale: locale)
        let lastWeight = Formatters.weight(last.bestWeight, locale: locale)
        return String(
            localized: "From \(firstWeight) to \(lastWeight) kilograms"
        )
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct ExerciseHistoryList: View {
    let detail: ExerciseDetailModel.Detail
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text(detail.historySessions.allSatisfy { $0.performedAt == nil }
                ? String(localized: "Recent sets")
                : String(localized: "Recent training"))
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            if detail.historySessions.isEmpty {
                Text("You have not logged this exercise yet.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
                    .padding(LacticSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LacticColor.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: LacticRadius.card)
                    )
            } else {
                ForEach(detail.historySessions) { session in
                    ExerciseHistorySessionCard(
                        session: session,
                        isPersonalRecord: session.bestWeight == detail.bestWeight,
                        locale: locale
                    )
                }
            }
        }
    }
}

private struct ExerciseHistorySessionCard: View {
    let session: ExerciseDetailModel.HistorySession
    let isPersonalRecord: Bool
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(session.performedAt
                        .map { Formatters.date($0, locale: locale) } ?? String(localized: "Logged set"))
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)
                    Text("\(session.sets.count) sets · \(session.totalReps) reps")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textSecondary)
                }
                Spacer(minLength: LacticSpacing.sm)
                if isPersonalRecord {
                    StatusBadge(String(localized: "Personal best"), tone: .positive)
                }
            }

            ForEach(session.sets) { set in
                HStack {
                    Text("Set \(set.position)")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                    Spacer(minLength: LacticSpacing.sm)
                    Text("\(Formatters.weight(set.weightKg, locale: locale)) kg × \(set.reps)")
                        .font(.lacticNumeric)
                        .foregroundStyle(LacticColor.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(LacticSpacing.lg)
        .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card)
                .strokeBorder(isPersonalRecord ? LacticColor.accent : LacticColor.border, lineWidth: 1)
        }
    }
}
