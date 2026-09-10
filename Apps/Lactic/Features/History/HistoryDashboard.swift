import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct HistoryDashboard: View {
    let snapshot: HistoryModel.Snapshot
    let locale: AppLocale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                HistoryOverview(snapshot: snapshot)

                if !snapshot.inProgress.isEmpty {
                    HistorySection(title: String(localized: "In progress")) {
                        ForEach(snapshot.inProgress) { session in
                            HistorySessionLink(session: session, locale: locale)
                        }
                    }
                }

                if !snapshot.completed.isEmpty {
                    HistorySection(title: String(localized: "Completed sessions")) {
                        ForEach(snapshot.completed) { session in
                            HistorySessionLink(session: session, locale: locale)
                        }
                    }
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private struct HistoryOverview: View {
    let snapshot: HistoryModel.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Label("Training record", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)

                Text("Progress built one session at a time.")
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: LacticSpacing.xl) {
                    metrics
                }
                VStack(alignment: .leading, spacing: LacticSpacing.md) {
                    metrics
                }
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }

    @ViewBuilder
    private var metrics: some View {
        HistoryMetric(value: snapshot.completed.count.formatted(), label: String(localized: "Sessions"))
        HistoryMetric(value: snapshot.distinctWorkoutCount.formatted(), label: String(localized: "Workouts"))
        HistoryMetric(
            value: Formatters.duration(seconds: Int(snapshot.totalTrainingTime)),
            label: String(localized: "Training time")
        )
    }
}

private struct HistoryMetric: View {
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

private struct HistorySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text(title)
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)
            LazyVStack(spacing: LacticSpacing.sm) {
                content
            }
        }
    }
}

private struct HistorySessionLink: View {
    let session: WorkoutSession
    let locale: AppLocale

    var body: some View {
        NavigationLink {
            SessionDetailView(sessionID: session.id)
        } label: {
            HStack(alignment: .center, spacing: LacticSpacing.md) {
                Image(systemName: session.isInProgress ? "bolt.fill" : "checkmark")
                    .font(.lacticHeadline)
                    .foregroundStyle(session.isInProgress ? LacticColor.info : LacticColor.heroSurface)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                    .background(
                        session.isInProgress ? LacticColor.infoSurface : LacticColor.brand,
                        in: RoundedRectangle(cornerRadius: LacticRadius.control)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(session.workoutName ?? String(localized: "Workout"))
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(startedAt)
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)

                    if let notes = session.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textMuted)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: LacticSpacing.sm)

                VStack(alignment: .trailing, spacing: LacticSpacing.xs) {
                    if let duration = ClientFormat.duration(of: session) {
                        Text(duration)
                            .font(.lacticCaption.monospacedDigit())
                            .foregroundStyle(LacticColor.textSecondary)
                    } else {
                        StatusBadge(String(localized: "In progress"), tone: .informative)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LacticColor.textMuted)
                        .accessibilityHidden(true)
                }
            }
            .padding(LacticSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: LacticRadius.card)
                    .strokeBorder(LacticColor.border, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this session")
    }

    private var startedAt: String {
        guard let startedAt = session.startedAt else { return String(localized: "Not started") }
        return Formatters.dateTime(startedAt, locale: locale)
    }
}
