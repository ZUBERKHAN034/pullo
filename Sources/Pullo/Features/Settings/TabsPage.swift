import AppKit
import SwiftUI

struct TabsPage: View {
    private struct Editing: Identifiable {
        let filter: SavedFilter
        let teamReviews: Bool

        var id: UUID { filter.id }
    }

    @Environment(AccountStore.self) private var accounts
    @State private var editing: Editing?
    @State private var editingRunTab: RunTab?

    var body: some View {
        Form {
            tabsSection
            runTabsSection
        }
        .sheet(item: $editing) { editing in
            TabEditor(filter: editing.filter, startsWithTeamReviews: editing.teamReviews) { saved in
                var filters = accounts.tabs
                if let index = filters.firstIndex(where: { $0.id == saved.id }) {
                    filters[index] = saved
                } else {
                    filters.append(saved)
                }
                accounts.setTabs(filters)
            }
        }
        .sheet(item: $editingRunTab) { tab in
            RunTabEditor(tab: tab) { saved in
                var tabs = accounts.runTabs
                if let index = tabs.firstIndex(where: { $0.id == saved.id }) {
                    tabs[index] = saved
                } else {
                    tabs.append(saved)
                }
                accounts.setRunTabs(tabs)
            }
        }
    }

    private func edit(_ filter: SavedFilter, teamReviews: Bool = false) {
        editing = Editing(filter: filter, teamReviews: teamReviews)
    }

    private func scoped(_ text: String, to account: String?) -> String {
        guard accounts.accounts.count > 1, let account else { return text }
        return "@\(account) · \(text)"
    }

    private var runTabsSection: some View {
        let tabs = accounts.runTabs
        let missingPresets = RunTab.Preset.allCases.filter { preset in !tabs.contains { $0.preset == preset } }
        return Section {
            ForEach(tabs) { tab in
                LabeledContent {
                    HStack(spacing: 6) {
                        Button("Edit…") { editingRunTab = tab }
                        Button {
                            accounts.setRunTabs(tabs.filter { $0.id != tab.id })
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(tabs.count == 1)
                        .help(String(localized: "Remove"))
                        .accessibilityLabel(String(localized: "Remove"))
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tab.name)
                            Text(scoped(tab.summary, to: tab.account)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .onMove { from, to in
                var reordered = tabs
                reordered.move(fromOffsets: from, toOffset: to)
                accounts.setRunTabs(reordered)
            }
            HStack {
                Menu("Add tab") {
                    Button("Blank…") { editingRunTab = RunTab(name: "") }
                    Section("Examples") {
                        ForEach(RunTab.examples) { example in
                            Button(example.name) { editingRunTab = example }
                        }
                    }
                }
                .fixedSize()
                Spacer()
                if !missingPresets.isEmpty {
                    Button("Restore default tabs") {
                        accounts.setRunTabs(missingPresets.map(RunTab.builtIn) + tabs)
                    }
                }
            }
        } header: {
            Text("Actions tabs")
        } footer: {
            Text("Each one is a tab on the Actions side of the panel, in this order. Drag to reorder.")
        }
    }

    private var tabsSection: some View {
        let filters = accounts.tabs
        let missingPresets = ([.mine, .review] as [SavedFilter.Preset]).filter { preset in !filters.contains { $0.preset == preset } }
        return Section {
            ForEach(filters) { filter in
                LabeledContent {
                    HStack(spacing: 6) {
                        Button("Edit…") { edit(filter) }
                        Button {
                            accounts.setTabs(filters.filter { $0.id != filter.id })
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(filters.count == 1)
                        .help(String(localized: "Remove"))
                        .accessibilityLabel(String(localized: "Remove"))
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(filter.name)
                            Text(scoped(filter.query, to: filter.account)).font(.caption.monospaced()).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onMove { from, to in
                var reordered = filters
                reordered.move(fromOffsets: from, toOffset: to)
                accounts.setTabs(reordered)
            }
            HStack {
                Menu("Add tab") {
                    Button("Blank…") { edit(SavedFilter(name: "", query: "author:@me")) }
                    Section("Examples") {
                        Button("Team reviews") { edit(SavedFilter(name: String(localized: "Team reviews"), query: ""), teamReviews: true) }
                        ForEach(SavedFilter.examples, id: \.query) { example in
                            Button(example.name) { edit(example) }
                        }
                    }
                }
                .fixedSize()
                Spacer()
                if !missingPresets.isEmpty {
                    Button("Restore default tabs") {
                        accounts.setTabs(missingPresets.map { SavedFilter.builtIn($0) } + filters)
                    }
                }
            }
        } header: {
            Text("Pull request tabs")
        } footer: {
            Text(
                "Each one is a tab in the panel, in this order. Drag to reorder. Alerts always follow your PRs and review requests, whatever tabs you keep."
            )
        }
    }
}

private struct TabEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.system) private var system
    @Environment(PRListModel.self) private var list
    @Environment(AccountStore.self) private var accounts
    @State private var filter: SavedFilter
    @State private var fields: PRQuery
    @State private var showsQuery: Bool
    @State private var myTeams: [String]?
    let onSave: (SavedFilter) -> Void

    init(filter: SavedFilter, startsWithTeamReviews: Bool = false, onSave: @escaping (SavedFilter) -> Void) {
        var fields = PRQuery(parsing: filter.query)
        if startsWithTeamReviews { fields.review = .requestedFromTeams }
        _filter = State(initialValue: filter)
        _fields = State(initialValue: fields)
        _showsQuery = State(initialValue: !fields.extra.isEmpty)
        self.onSave = onSave
    }

    private func field<Value>(_ path: WritableKeyPath<PRQuery, Value>) -> Binding<Value> {
        Binding {
            fields[keyPath: path]
        } set: {
            fields[keyPath: path] = $0
            filter.query = fields.text
        }
    }

    private var query: Binding<String> {
        Binding {
            filter.query
        } set: {
            filter.query = $0
            fields = PRQuery(parsing: $0)
        }
    }

    private var repos: [String] {
        var known = Set<String>()
        return (list.tabs + [.mine, .review]).flatMap(list.prs(in:)).map(\.repo)
            .filter { known.insert($0.lowercased()).inserted }.sorted()
    }

    private var review: Binding<PRQuery.Review> {
        Binding {
            fields.review
        } set: {
            fields.review = $0
            if $0 == .requestedFromTeams, fields.teams.isEmpty { fields.teams = myTeams ?? [] }
            filter.query = fields.text
        }
    }

    private var team: Binding<String> {
        Binding {
            fields.teams.count == 1 ? fields.teams[0] : ""
        } set: {
            fields.teams = $0.isEmpty ? (myTeams ?? []) : [$0]
            filter.query = fields.text
        }
    }

    private var teamChoices: [String] {
        let picked = fields.teams.count == 1 ? fields.teams : []
        return (myTeams ?? []) + picked.filter { !(myTeams ?? []).contains($0) }
    }

    private func useTeamReviews() {
        if filter.name.allSatisfy(\.isWhitespace) { filter.name = String(localized: "Team reviews") }
        fields = PRQuery()
        fields.review = .requestedFromTeams
        fields.teams = myTeams ?? []
        filter.query = fields.text
    }

    private func loadTeams() async {
        let logins = filter.account.map { [$0] } ?? accounts.accounts.map(\.login)
        myTeams = await accounts.teams(of: logins)
        if fields.review == .requestedFromTeams, fields.teams.isEmpty {
            fields.teams = myTeams ?? []
            filter.query = fields.text
        }
    }

    private func use(_ example: SavedFilter) {
        if filter.name.allSatisfy(\.isWhitespace) { filter.name = example.name }
        query.wrappedValue = example.query
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $filter.name, prompt: Text("Bugs in the API"))
                    AccountPicker(account: $filter.account)
                    Picker("Sort by", selection: $filter.sort) {
                        Text("Default").tag(SavedFilter.Sort?.none)
                        ForEach(SavedFilter.Sort.allCases, id: \.self) { Text($0.title).tag(SavedFilter.Sort?.some($0)) }
                    }
                }
                Section {
                    Picker("Author", selection: field(\.author)) {
                        ForEach(PRQuery.Author.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if fields.author == .user {
                        TextField("GitHub user", text: field(\.user), prompt: Text(verbatim: "octocat"))
                    }
                    LabeledContent("Repository") {
                        HStack(spacing: 4) {
                            TextField("Repository", text: field(\.repo), prompt: Text("Any"))
                                .labelsHidden()
                            Menu {
                                Button("Any") { field(\.repo).wrappedValue = "" }
                                if !repos.isEmpty {
                                    Section("In your tabs") {
                                        ForEach(repos, id: \.self) { repo in
                                            Button { field(\.repo).wrappedValue = repo } label: { Text(verbatim: repo) }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .accessibilityLabel(String(localized: "Pick a repository"))
                        }
                    }
                    Picker("Review", selection: review) {
                        ForEach(PRQuery.Review.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if fields.review == .requestedFromTeams {
                        if myTeams == nil {
                            LabeledContent("Team") { ProgressView().controlSize(.small) }
                        } else if teamChoices.isEmpty {
                            TextField("Team", text: team, prompt: Text(verbatim: "acme/backend"))
                        } else {
                            Picker("Team", selection: team) {
                                Text("All my teams").tag("")
                                ForEach(teamChoices, id: \.self) { Text(verbatim: $0).tag($0) }
                            }
                        }
                    }
                    Picker("Checks", selection: field(\.checks)) {
                        ForEach(PRQuery.Checks.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("State", selection: field(\.state)) {
                        ForEach(PRQuery.State.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Label", text: field(\.label), prompt: Text("Any"))
                } header: {
                    HStack {
                        Text("Show pull requests where")
                        Spacer()
                        Menu("Examples") {
                            Button("Team reviews") { useTeamReviews() }
                            ForEach(SavedFilter.examples, id: \.query) { example in
                                Button(example.name) { use(example) }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .font(.callout)
                    }
                }
                Section {
                    DisclosureGroup("GitHub search", isExpanded: $showsQuery) {
                        TextField("Search query", text: query, prompt: Text(verbatim: "repo:acme/api label:bug"), axis: .vertical)
                            .labelsHidden()
                            .font(.body.monospaced())
                            .lineLimit(2...4)
                    }
                } footer: {
                    HStack {
                        Text("Anything the fields can't show stays in the search.")
                        Spacer()
                        Link(
                            "Search syntax",
                            destination: URL(
                                static: "https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests"
                            )
                        )
                        Button("Preview on GitHub") { filter.webURL.map(system.open) }
                            .buttonStyle(.link)
                            .disabled(filter.query.allSatisfy(\.isWhitespace))
                    }
                    .font(.caption)
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 570)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(filter)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!filter.isComplete || !fields.isComplete)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 480)
        .task(id: filter.account) { await loadTeams() }
    }
}

struct RunTabEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ActionsModel.self) private var actions
    @State var tab: RunTab
    let onSave: (RunTab) -> Void

    private var seen: [WorkflowRun] { actions.allRuns.filter { tab.applies(to: $0.account) } }

    private var repos: [String] {
        var known = Set<String>()
        return seen.map(\.repo).filter { known.insert($0.lowercased()).inserted }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $tab.name, prompt: Text("Production deploys"))
                    AccountPicker(account: $tab.account)
                }
                Section {
                    Picker("Started by", selection: $tab.startedBy) {
                        ForEach(RunTab.Starter.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if tab.startedBy == .user {
                        TextField("GitHub user", text: $tab.user, prompt: Text(verbatim: "octocat"))
                    }
                    LabeledContent("Repository") {
                        HStack(spacing: 4) {
                            TextField("Repository", text: $tab.repo, prompt: Text("Any"))
                                .labelsHidden()
                            Menu {
                                Button("Any") { tab.repo = "" }
                                if !repos.isEmpty {
                                    Section("Watched by Pullo") {
                                        ForEach(repos, id: \.self) { repo in
                                            Button { tab.repo = repo } label: { Text(verbatim: repo) }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .accessibilityLabel(String(localized: "Pick a repository"))
                        }
                    }
                    TextField("Workflow name contains", text: $tab.workflow, prompt: Text("Any"))
                    TextField("Branch", text: $tab.branch, prompt: Text("Any"))
                    Picker("Event", selection: $tab.event) {
                        ForEach(RunTab.Event.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Status", selection: $tab.status) {
                        ForEach(RunTab.Status.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Show runs where")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("For the branch, end with * to match the start, like release/*.")
                        Text(
                            "Matches \(seen.filter { tab.includes($0, login: $0.account) }.count) of the \(seen.count) runs Pullo sees right now."
                        )
                    }
                    .font(.caption)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(tab)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!tab.isComplete)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
    }
}

private struct AccountPicker: View {
    @Environment(AccountStore.self) private var accounts
    @Binding var account: String?

    var body: some View {
        if accounts.accounts.count > 1 || account != nil {
            Picker("Account", selection: $account) {
                Text("All accounts").tag(String?.none)
                ForEach(accounts.accounts) { Text(verbatim: "@\($0.login)").tag(String?.some($0.login)) }
            }
        }
    }
}
