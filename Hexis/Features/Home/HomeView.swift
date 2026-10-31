import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Program> { $0.isActive }) private var programs: [Program]
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "inProgress" }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var openSessions: [WorkoutSession]
    @Query(sort: \Gym.name) private var gyms: [Gym]
    @AppStorage("selectedGymID") private var selectedGymID = ""
    @AppStorage("gymChosenOn") private var gymChosenOn = ""
    /// The running session, presented by `RootView` above the pager.
    @Binding var running: WorkoutSession?
    @State private var location = LocationService()
    @State private var adjustments = SessionAdjustments.none
    @State private var speedNote: SessionAdjustments.Note?

    private var selectedGym: Gym? { gyms.first { $0.id.uuidString == selectedGymID } ?? gyms.first }

    @Query private var exercises: [Exercise]
    @Query private var deloadWeeks: [DeloadWeek]
    @Query(filter: #Predicate<WorkoutSession> { $0.stateRaw == "finished" }) private var finished: [WorkoutSession]
    @State private var abandoning = false

    private var templates: [WorkoutTemplate] { (programs.first?.templates ?? []).sorted { $0.order < $1.order } }
    private var exerciseByID: [UUID: Exercise] { Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) }) }

    private var resumable: (WorkoutSession, WorkoutTemplate)? {
        guard let session = openSessions.first,
              let template = templates.first(where: { $0.id == session.templateID })
        else { return nil }
        return (session, template)
    }

    private var rotation: WeekRotation {
        WeekRotation.make(templates: templates, sessions: finished.map { (templateID: $0.templateID, date: $0.startedAt) })
    }

    private var today: WorkoutTemplate? {
        rotation.next.flatMap { id in templates.first { $0.id == id } }
    }

    private var weekTemplates: [WorkoutTemplate] {
        rotation.short ? templates.filter { ProgramCatalog.shortWeek.contains($0.name) } : ProgramCatalog.usualWeek(templates)
    }

    private var weekNotes: [SessionAdjustments.Note] {
        rotation.note(names: Dictionary(templates.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })).map { [$0] } ?? []
    }

    var body: some View {
        Group {
            if let (session, template) = resumable {
                resumeContent(session, template)
            } else if let suggested = today {
                chooser(suggested)
            } else {
                PlaceholderView(
                    systemImage: "figure.strengthtraining.traditional",
                    title: "Pas de séance",
                    subtitle: "Importe un programme dans l'onglet Programme."
                )
            }
        }
        .padding(.bottom, Theme.Spacing.m)
        .screenBackground()
        .task {
            GymDefaults.seed(in: context)
            await GymDefaults.locateMissing(in: context)
            await detectGym()
        }
        .task(id: "\(today?.name ?? "")\(rotation.short)") { if let today { HomeShown.save(.init(date: .now, session: today.name, short: rotation.short)) } }
    }

    private var gymPicker: some View {
        Picker("Salle", selection: Binding(
            get: { selectedGym?.id.uuidString ?? "" },
            set: { selectedGymID = $0; gymChosenOn = Self.dayKey }
        )) {
            ForEach(gyms) { Text($0.name).tag($0.id.uuidString) }
        }
        .pickerStyle(.menu)
        .tint(Theme.Colors.accent)
        .opacity(gyms.isEmpty ? 0 : 1)
    }

    private func resumeContent(_ session: WorkoutSession, _ template: WorkoutTemplate) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            summary(template, caption: "Séance en cours")
            Button("Reprendre") { running = session }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.Spacing.m)
            Button("Abandonner la séance") { abandoning = true }
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .alert("Abandonner la séance en cours ?", isPresented: $abandoning) {
                    Button("Annuler", role: .cancel) {}
                    Button("Abandonner", role: .destructive) { abandon(session) }
                } message: {
                    Text("Ses séries seront supprimées.")
                }
        }
        .frame(maxHeight: .infinity)
        // Not a scroll view, so `contentMargins` does not apply: keep the buttons above the floating tab bar.
        .padding(.bottom, Theme.Layout.tabBarClearance)
    }

    /// Suggested session with a big start button, then the other sessions of this kind of week (usual or 3-session) to pick from.
    private func chooser(_ suggested: WorkoutTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if Edition.hasGymPicker {
                    gymPicker
                    GymSetupHint(gyms: gyms)
                }
                if Edition.isElle {
                    StreakCard(streak: HabitStreak(sessionDates: finished.map(\.startedAt), weeklyTarget: max(weekTemplates.count, 1)))
                }
                TrainingStatusSection(compact: true)
                CheerLine(alignment: .leading) { context in await Cheer.home(in: context) }
                TemplateCard(template: suggested, summary: learnedSummary(suggested), trailingSymbol: nil, hero: true)
                AdjustmentsCard(notes: weekNotes + adjustments.notes + (speedNote.map { [$0] } ?? []))
                Button("Commencer") { start(suggested) }
                    .buttonStyle(PrimaryButtonStyle())
                OtherSessionsCard(names: weekTemplates.filter { $0.id != suggested.id }.map { ($0.id, $0.name) }) { id in
                    if let template = templates.first(where: { $0.id == id }) { start(template) }
                }
                BuildStamp()
            }
            .padding(Theme.Spacing.m)
        }
        .task(id: "\(suggested.id)\(selectedGymID)\(finished.count)") {
            AutoDeload.planIfDue(in: context)
            adjustments = SessionAdjuster.load(template: suggested, gymID: selectedGym?.id, context: context)
            speedNote = SpeedInsights.advice(sessions: finished)
        }
    }

    /// Template summary whose duration comes from the real sessions once there are enough.
    private func learnedSummary(_ template: WorkoutTemplate) -> TemplateSummary {
        var summary = TemplateSummary(template, exercises: exerciseByID)
        if let minutes = DurationStats.minutes(for: template.id, sessions: finished, cycle: TrainingCycle(deloadStarts: deloadWeeks.map(\.start))) { summary.minutes = minutes }
        return summary
    }

    private func abandon(_ session: WorkoutSession) { SessionCloser.discard(session, context: context) }

    private func summary(_ template: WorkoutTemplate, caption: String) -> some View {
        let count = template.blocks.reduce(0) { $0 + $1.exercises.count }
        return PlaceholderView(
            systemImage: "figure.strengthtraining.traditional",
            title: template.name,
            subtitle: "\(caption) · \(count) exercices"
        )
    }

    /// Selects the gym whose radius contains the current position, when one is known.
    private func detectGym() async {
        let candidates = gyms.compactMap { gym -> GymLocator.Candidate? in
            guard let lat = gym.latitude, let lon = gym.longitude else { return nil }
            return .init(id: gym.id, latitude: lat, longitude: lon, radius: gym.radius)
        }
        // A gym picked by hand today is kept, wherever the phone is.
        guard gymChosenOn != Self.dayKey else { return }
        if !candidates.isEmpty, let here = await location.currentLocation(),
           let id = GymLocator.nearest(to: here, among: candidates) {
            selectedGymID = id.uuidString
            return
        }
        let wanted = GymDefaults.fallbackName(on: .now)
        if let gym = gyms.first(where: { $0.name.contains(wanted) }) { selectedGymID = gym.id.uuidString }
    }

    private static var dayKey: String { Date.now.formatted(.iso8601.year().month().day()) }

    private func start(_ template: WorkoutTemplate) {
        AutoDeload.planIfDue(in: context)
        let session = WorkoutSession(gymID: selectedGym?.id, templateID: template.id)
        context.insert(session)
        context.saveReportingFailure()
        SoundService.play(.sessionStart)
        running = session
    }
}

#Preview {
    HomeView(running: .constant(nil))
        .modelContainer(for: Program.self, inMemory: true)
        .appAppearance()
}
