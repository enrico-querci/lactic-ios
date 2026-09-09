#if DEBUG
    import LacticUI
    import SwiftUI

    /// A visual check of every LacticUI component in one place.
    ///
    /// DEBUG-only and reachable from the signed-in placeholder. A design system
    /// that is only ever seen one component at a time drifts, and the dark
    /// palette in particular is new rather than ported, so it needs somewhere it
    /// can be looked at whole.
    struct DesignSystemGalleryView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                    NavigationLink("Workout preview") { WorkoutDesignPreview() }
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.accent)

                    section("Typography") {
                        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                            Text("Lactic").font(.lacticDisplay)
                            Text("Upper body strength").font(.lacticTitle)
                            Text("Your next session").font(.lacticHeadline)
                            Text("Follow your programme, log your sets.").font(.lacticBody)
                            Text("72.5 kg × 8").font(.lacticNumeric)
                            Text("01:30").font(.lacticTimer)
                        }
                    }

                    section("Palette") {
                        HStack(spacing: LacticSpacing.sm) {
                            swatch("Lime", color: LacticColor.brand)
                            swatch("Graphite", color: LacticColor.heroSurface)
                            swatch("Accent", color: LacticColor.accent)
                        }
                    }

                    section("Buttons") {
                        VStack(spacing: LacticSpacing.sm) {
                            Button("Start workout") {}.lacticButton()
                            Button("Add set") {}.lacticButton(.secondary)
                            Button("Delete account") {}.lacticButton(.danger)
                            Button("Disabled") {}.lacticButton(isEnabled: false)
                        }
                    }

                    section("Badges") {
                        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                            HStack {
                                StatusBadge("Active", tone: .positive)
                                StatusBadge("Paused", tone: .caution)
                                StatusBadge("Completed")
                                StatusBadge("Custom", tone: .informative)
                            }
                            HStack {
                                VolumeChip(muscleGroup: "Chest", sets: 12)
                                VolumeChip(muscleGroup: "Triceps", sets: 9)
                                PositionBadge("A")
                                PositionBadge("B")
                            }
                        }
                    }

                    section("Numeric entry") {
                        HStack(spacing: LacticSpacing.sm) {
                            NumericField(kind: .weight, value: Decimal(string: "72.5") ?? 0) { _ in }
                            NumericField(kind: .reps, value: 8) { _ in }
                        }
                    }

                    section("States") {
                        VStack(spacing: LacticSpacing.md) {
                            LoadingView("Loading your programme")
                            EmptyStateView(
                                title: "No programmes yet",
                                message: "Your coach has not assigned anything.",
                                systemImage: "list.bullet.rectangle"
                            )
                            ErrorStateView(message: "Could not connect to the server.") {}
                            ErrorBanner(message: "That set could not be saved.") {}
                        }
                    }
                }
                .padding(LacticSpacing.lg)
            }
            .background(LacticColor.surface)
            .navigationTitle("Design system")
            .navigationBarTitleDisplayMode(.inline)
        }

        private func section(
            _ title: String,
            @ViewBuilder content: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text(title)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                content()
            }
        }

        private func swatch(_ title: String, color: Color) -> some View {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                RoundedRectangle(cornerRadius: LacticRadius.control)
                    .fill(color)
                    .frame(height: 64)
                Text(title)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
        }
    }
#endif
