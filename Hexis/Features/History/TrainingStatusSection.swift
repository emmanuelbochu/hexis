import SwiftData
import SwiftUI

/// Regularity and deload status, shared by the home screen and the insights screen.
struct TrainingStatusSection: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }) private var sessions: [WorkoutSession]
    @Query private var deloads: [DeloadWeek]
    @Query(filter: #Predicate<Program> { $0.isActive }) private var programs: [Program]
    @State private var advice: DeloadAdvice?
    /// One discreet line linking to the analysis, for the home screen.
    var compact = false

    private var currentWeek: Date { WeekReview.weekStart(containing: .now) }
    private var plannedWeek: DeloadWeek? { deloads.filter { $0.start >= currentWeek }.min { $0.start < $1.start } }

    var body: some View {
        content
            .task(id: sessions.count * 100 + deloads.count) {
                advice = AutoDeload.advice(in: context)
            }
    }

    @ViewBuilder private var content: some View {
        if compact {
            compactLine
        } else {
            full
        }
    }

    @ViewBuilder private var compactLine: some View {
        let text = plannedWeek.map { $0.start == currentWeek ? "Semaine de déload : moitié des séries" : nil }
            ?? advice.map { "Déload conseillé · semaine du \($0.weekStart.formatted(.dateTime.day().month(.abbreviated)))" }
        if let text {
            NavigationLink { InsightsView() } label: {
                Label(text, systemImage: "arrow.down.right.circle.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    private var full: some View {
        VStack(spacing: Theme.Spacing.m) {
            if !sessions.isEmpty {
                RegularityCard(regularity: Regularity(
                    sessionDates: sessions.map(\.startedAt), weeklyTarget: programs.first.map { ProgramCatalog.usualWeek($0.templates).count } ?? 3
                ))
            }
            if let planned = plannedWeek {
                DeloadCard(mode: .planned(start: planned.start, isCurrent: planned.start == currentWeek))
            } else if let advice {
                DeloadCard(mode: .advice(advice, plan: { plan(advice) }))
            }
        }
    }

    private func plan(_ advice: DeloadAdvice) {
        context.insert(DeloadWeek(start: advice.weekStart, reason: advice.reason))
        context.saveReportingFailure()
    }
}
