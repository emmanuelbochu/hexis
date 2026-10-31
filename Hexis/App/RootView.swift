import SwiftData
import SwiftUI

/// All screens sit side by side in one native pager: swipe moves from one to the next, across Muscu and Alimentation.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("appPageV2") private var page = 0
    /// Last tab used in each part, so switching back returns to it.
    @State private var lastWorkoutTab = 0
    @State private var lastNutritionTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var running: WorkoutSession?
    @State private var location = LocationService()
    @State private var reminderFile: URL?
    private let saves = SaveMonitor.shared

    private static let workoutItems: [RootTabBar.Item] = [
        .init(title: "Accueil", systemImage: "house.fill"), .init(title: "Programme", systemImage: "list.bullet.rectangle.fill"),
        .init(title: "Historique", systemImage: "clock.arrow.circlepath"),
    ]
    private static let nutritionItems: [RootTabBar.Item] = [
        .init(title: "Aujourd'hui", systemImage: "fork.knife"), .init(title: "Plan", systemImage: "calendar"),
        .init(title: "Courses", systemImage: "cart.fill"),
    ]
    /// Pages 0..<3 are Muscu, 3..<6 Alimentation.
    private static let workoutPages = 3
    private static let pageCount = Edition.hasNutrition ? 6 : 3

    private var mode: AppMode { page < Self.workoutPages ? .workout : .nutrition }

    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { new in
                withAnimation(.snappy) { page = new == .workout ? lastWorkoutTab : Self.workoutPages + lastNutritionTab }
            }
        )
    }

    private var tabBinding: Binding<Int> {
        Binding(
            get: { mode == .workout ? page : page - Self.workoutPages },
            set: { page = (mode == .workout ? 0 : Self.workoutPages) + $0 }
        )
    }

    /// A horizontal swipe on the top row switches between Muscu and Alimentation, from any screen.
    private var modeSwipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { drag in
            guard Edition.hasNutrition, abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
            modeBinding.wrappedValue = drag.translation.width < 0 ? .nutrition : .workout
        }
    }

    /// Closes the sessions left open (also the one on screen, e.g. after a locked phone) and drops the screen of a closed one.
    private func closeFinishedSessions() async {
        let runningID = running?.id
        let closed = await SessionCloser.run(in: context, location: location)
        if let runningID, closed.contains(runningID) { running = nil }
    }

    var body: some View {
        // One single navigation stack around the pager: several stacks side by side in a page TabView
        // make UIKit mix their navigation bars when swiping (crash). Pushed screens cover the whole pager.
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if Edition.hasNutrition { ModeSwitcher(mode: modeBinding) } else { Color.clear.frame(height: 36) }
                }
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .overlay(alignment: .trailing) { AppearanceToggle().padding(.trailing, Theme.Spacing.m) }
                    .simultaneousGesture(modeSwipe)
                TabView(selection: $page) {
                    HomeView(running: $running).tag(0)
                    ProgramView().tag(1)
                    HistoryView().tag(2)
                    if Edition.hasNutrition {
                        NutritionTodayView().tag(3)
                        NutritionPlanView().tag(4)
                        ShoppingView().tag(5)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Room under the lists for the glass bar floating over them (not a safe-area inset, see CLAUDE.md).
                .contentMargins(.bottom, Theme.Layout.tabBarClearance, for: .scrollContent)
            }
            // Over the pages, not under them: the glass bar bends what scrolls behind it.
            .overlay(alignment: .bottom) {
                RootTabBar(items: mode == .workout ? Self.workoutItems : Self.nutritionItems, selection: tabBinding)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.Colors.accent)
        .fullScreenCover(item: $running) { ActiveWorkoutView(session: $0) }
        .sheet(item: $reminderFile) { BackupReminderView(file: $0).appAppearance() }
        .overlay(alignment: .top) {
            if saves.failed {
                Button { saves.dismiss() } label: {
                    Label("Sauvegarde impossible : touche pour fermer", systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.s)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.surface)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if Edition.hasNutrition {
                StockReconciler.run(in: context)
                FlatStockBook.settleCarry(in: context)
                NotificationService.scheduleShoppingReady()
                Task { await PlanAutoAdjust.runIfDue(in: context) }
            }
            Task { await closeFinishedSessions() }
            Task { await NotificationHub.refresh(in: context) }
        }
        .onChange(of: running) { _, session in
            // A session just ended: the notifications planned from the previous state are stale.
            if session == nil { Task { await NotificationHub.refresh(in: context) } }
        }
        .onChange(of: page, initial: true) {
            if page >= Self.pageCount { page = Edition.hasNutrition ? Self.workoutPages : 0 }
            if page < Self.workoutPages { lastWorkoutTab = page } else { lastNutritionTab = min(page - Self.workoutPages, 2) }
        }
        .task {
            SoundService.prepare()
            let launch = Date.now.timeIntervalSince(Diagnostics.launchedAt)
            if launch > Diagnostics.slowLaunch { Diagnostics.record(.slowLaunch, String(format: "%.1f s to the first screen", launch)) }
            AutoBackup.restoreIfEmpty(in: context)
            ProgramSync.sync(in: context)
            HistorySeed.seed(in: context)
            if Edition.hasNutrition {
                NutritionDefaults.seed(in: context)
                StockReconciler.run(in: context)
                FlatStockBook.settleCarry(in: context)
                NotificationService.scheduleShoppingReady()
                Task { await PlanAutoAdjust.runIfDue(in: context) }
            }
            AutoBackup.saveIfStale(from: context)
            ProfileExpiry.scheduleReminder()
            await closeFinishedSessions()
            await NotificationHub.refresh(in: context)
            if running == nil, AutoBackup.reminderDue(), let file = AutoBackup.latestFile() {
                AutoBackup.markReminded()
                reminderFile = file
            }
        }
    }
}

#Preview {
    RootView()
        .appAppearance()
}
