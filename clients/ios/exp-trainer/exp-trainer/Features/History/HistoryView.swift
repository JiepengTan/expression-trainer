import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if completedSessions.isEmpty {
                ContentUnavailableView {
                    Label("还没有训练记录", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("完成第一次训练后，可以在这里回看复盘或同题再练。")
                } actions: {
                    Button("开始训练") {
                        app.selectedTab = .training
                        app.presentNewTraining()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ETColor.orange)
                }
            } else {
                List {
                    ForEach(groupedDates, id: \.date) { group in
                        Section(group.date.formatted(date: .complete, time: .omitted)) {
                            ForEach(group.sessions) { session in
                                SessionCard(session: session) { app.routes.append(.report(session.id)) }
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { app.overlay = .confirmDelete(session.id) } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button { app.presentNewTraining(prefill: session) } label: {
                                            Label("再练", systemImage: "arrow.counterclockwise")
                                        }
                                        .tint(ETColor.teal)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .expressionScreen()
        .navigationTitle("历史")
        .accessibilityIdentifier(completedSessions.isEmpty ? "screen.history.empty" : "screen.history.list")
        .onAppear { app.reload() }
    }

    private var completedSessions: [TrainingSessionRecord] {
        app.sessions.filter { $0.state == .completed }
    }

    private var groupedDates: [(date: Date, sessions: [TrainingSessionRecord])] {
        let calendar = Calendar.current
        return Dictionary(grouping: completedSessions) { calendar.startOfDay(for: $0.createdAt) }
            .map { (date: $0.key, sessions: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }
}
