import Foundation
import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct SessionSummaryView: View {
    let detail: SessionDetailModel.Detail
    let locale: AppLocale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                SessionOverview(detail: detail, locale: locale)

                if let notes = detail.session.notes, !notes.isEmpty {
                    SessionNote(notes: notes)
                }

                VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                    Text("Exercises")
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)

                    if detail.orderedExerciseLogs.isEmpty {
                        Text("No sets were logged in this session.")
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textMuted)
                            .padding(LacticSpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                LacticColor.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: LacticRadius.card)
                            )
                    } else {
                        ForEach(detail.orderedExerciseLogs) { log in
                            SessionExerciseCard(
                                log: log,
                                reference: detail.reference(for: log),
                                locale: locale
                            )
                        }
                    }
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private struct SessionOverview: View {
    let detail: SessionDetailModel.Detail
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Label {
                    Text(detail.session.isInProgress
                        ? String(localized: "Session in progress")
                        : String(localized: "Completed session"))
                } icon: {
                    Image(systemName: detail.session.isInProgress ? "bolt.fill" : "checkmark.circle.fill")
                }
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)

                Text(detail.workoutName ?? String(localized: "Workout"))
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)

                if let startedAt = detail.session.startedAt {
                    Text(Formatters.dateTime(startedAt, locale: locale))
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textOnHero)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: LacticSpacing.xl) { metrics }
                VStack(alignment: .leading, spacing: LacticSpacing.md) { metrics }
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }

    @ViewBuilder
    private var metrics: some View {
        SessionMetric(value: detail.totalSetCount.formatted(), label: String(localized: "Sets"))
        SessionMetric(value: detail.totalReps.formatted(), label: String(localized: "Reps"))
        SessionMetric(
            value: "\(Formatters.weight(detail.totalVolumeKg, locale: locale)) kg",
            label: String(localized: "Volume")
        )
        if let startedAt = detail.session.startedAt, let completedAt = detail.session.completedAt {
            SessionMetric(
                value: Formatters.duration(from: startedAt, to: completedAt),
                label: String(localized: "Duration")
            )
        }
    }
}

private struct SessionMetric: View {
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

private struct SessionNote: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Label("Session note", systemImage: "text.bubble")
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.accent)
            Text(notes)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.surfacePressed, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }
}

private struct SessionExerciseCard: View {
    let log: ExerciseLogDetail
    let reference: SessionDetailModel.ExerciseReference?
    let locale: AppLocale

    var body: some View {
        Group {
            if let exerciseID = reference?.exerciseID {
                NavigationLink {
                    ExerciseDetailView(exerciseID: exerciseID)
                } label: {
                    cardContent(showsNavigation: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens exercise progress")
            } else {
                cardContent(showsNavigation: false)
            }
        }
        .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }

    private func cardContent(showsNavigation: Bool) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(spacing: LacticSpacing.sm) {
                if let position = reference?.position {
                    PositionBadge(position)
                }
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(reference?.name ?? String(localized: "Exercise"))
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(log.setLogs.count) sets · \(totalReps) reps")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textSecondary)
                }
                Spacer(minLength: LacticSpacing.sm)
                if showsNavigation {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(LacticColor.accent)
                        .accessibilityHidden(true)
                }
            }

            if let notes = log.notes, !notes.isEmpty {
                Label(notes, systemImage: "text.bubble")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(LacticColor.border)

            ForEach(log.orderedSets) { set in
                SessionSetRow(setLog: set, locale: locale)
            }
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var totalReps: Int {
        log.setLogs.reduce(0) { $0 + $1.reps }
    }
}

private struct SessionSetRow: View {
    let setLog: SetLog
    let locale: AppLocale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LacticSpacing.md) {
                Text("Set \(setLog.position)")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                Spacer(minLength: LacticSpacing.sm)
                Text("\(Formatters.weight(setLog.weightKg, locale: locale)) kg")
                    .font(.lacticNumeric)
                Text("× \(setLog.reps)")
                    .font(.lacticNumeric)
                Text("\(Formatters.weight(volume, locale: locale)) kg")
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textMuted)
            }

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text("Set \(setLog.position)")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                Text("\(Formatters.weight(setLog.weightKg, locale: locale)) kg × \(setLog.reps) reps")
                    .font(.lacticNumeric)
                    .foregroundStyle(LacticColor.textPrimary)
                Text("\(Formatters.weight(volume, locale: locale)) kg volume")
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textMuted)
            }
        }
        .foregroundStyle(LacticColor.textPrimary)
        .accessibilityElement(children: .combine)
    }

    private var volume: Decimal {
        setLog.weightKg * Decimal(setLog.reps)
    }
}
