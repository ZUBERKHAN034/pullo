import AppKit
import SwiftUI

struct TabsPage: View {
    @Environment(AccountStore.self) private var accounts
    @State private var chosenLogin: String?
    @State private var editing: SavedFilter?
    @State private var editingRunTab: RunTab?

    private var login: String? {
        if let chosenLogin, accounts.accounts.contains(where: { $0.login == chosenLogin }) { return chosenLogin }
        return accounts.accounts.first?.login
    }

    var body: some View {
        Form {
            if let login {
                if accounts.accounts.count > 1 {
                    Section {
                        Picker("Account", selection: Binding(get: { login }, set: { chosenLogin = $0 })) {
                            ForEach(accounts.accounts) { Text(verbatim: "@\($0.login)").tag($0.login) }
                        }
                    }
                }
                tabsSection(for: login)
                runTabsSection(for: login)
            } else {
                Text("Add an account first.").foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editing) { filter in
            TabEditor(filter: filter) { saved in
                guard let login else { return }
                var filters = accounts.filters(for: login)
                if let index = filters.firstIndex(where: { $0.id == saved.id }) {
                    filters[index] = saved
                } else {
                    filters.append(saved)
                }
                accounts.setFilters(filters, for: login)
            }
        }
        .sheet(item: $editingRunTab) { tab in
            if let login {
                RunTabEditor(tab: tab, login: login) { saved in
                    var tabs = accounts.runTabs(for: login)
                    if let index = tabs.firstIndex(where: { $0.id == saved.id }) {
                        tabs[index] = saved
                    } else {
                        tabs.append(saved)
                    }
                    accounts.setRunTabs(tabs, for: login)
                }
            }
        }
    }

    private func runTabsSection(for login: String) -> some View {
        let tabs = accounts.runTabs(for: login)
        let missingPresets = RunTab.Preset.allCases.filter { preset in !tabs.contains { $0.preset == preset } }
        return Section {
            ForEach(tabs) { tab in
                LabeledContent {
                    HStack(spacing: 6) {
                        Button("Edit…") { editingRunTab = tab }
                        Button {
                            accounts.setRunTabs(tabs.filter { $0.id != tab.id }, for: login)
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
                            Text(tab.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .onMove { from, to in
                var reordered = tabs
                reordered.move(fromOffsets: from, toOffset: to)
                accounts.setRunTabs(reordered, for: login)
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
                        accounts.setRunTabs(missingPresets.map(RunTab.builtIn) + tabs, for: login)
                    }
                }
            }
        } header: {
            Text("Actions tabs for @\(login)")
        } footer: {
            Text("Each one is a tab on the Actions side of the panel, in this order. Drag to reorder.")
        }
    }

    private func tabsSection(for login: String) -> some View {
        let filters = accounts.filters(for: login)
        let missingPresets = ([.mine, .review] as [SavedFilter.Preset]).filter { preset in !filters.contains { $0.preset == preset } }
        return Section {
            ForEach(filters) { filter in
                LabeledContent {
                    HStack(spacing: 6) {
                        Button("Edit…") { editing = filter }
                        Button {
                            accounts.setFilters(filters.filter { $0.id != filter.id }, for: login)
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
                            Text(filter.query).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .onMove { from, to in
                var reordered = filters
                reordered.move(fromOffsets: from, toOffset: to)
                accounts.setFilters(reordered, for: login)
            }
            HStack {
                Menu("Add tab") {
                    Button("Blank…") { editing = SavedFilter(name: "", query: "") }
                    Section("Examples") {
                        ForEach(SavedFilter.examples, id: \.query) { example in
                            Button(example.name) { editing = example }
                        }
                    }
                }
                .fixedSize()
                Spacer()
                if !missingPresets.isEmpty {
                    Button("Restore default tabs") {
                        accounts.setFilters(missingPresets.map { SavedFilter.builtIn($0) } + filters, for: login)
                    }
                }
            }
        } header: {
            Text("Pull request tabs for @\(login)")
        } footer: {
            Text(
                .init(
                    String(
                        localized: "Each one is a tab in the panel, in this order. Drag to reorder. Write it like a GitHub search, for example `repo:acme/api label:bug` or `team-review-requested:acme/web`. Only open pull requests show up unless you add `is:closed` or `is:merged`. Alerts always follow your PRs and review requests, whatever tabs you keep."
                    )
                )
            )
        }
    }
}

private struct TabEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.system) private var system
    @State var filter: SavedFilter
    let onSave: (SavedFilter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $filter.name, prompt: Text("Bugs in the API"))
                }
                Section {
                    TextField("Search query", text: $filter.query, prompt: Text(verbatim: "repo:acme/api label:bug"), axis: .vertical)
                        .labelsHidden()
                        .font(.body.monospaced())
                        .lineLimit(2...4)
                } header: {
                    Text("Search query")
                } footer: {
                    HStack {
                        Link(
                            "Search syntax",
                            destination: URL(
                                static: "https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests"
                            )
                        )
                        Spacer()
                        Menu("Examples") {
                            ForEach(SavedFilter.examples, id: \.query) { example in
                                Button {
                                    if filter.name.allSatisfy(\.isWhitespace) { filter.name = example.name }
                                    filter.query = example.query
                                } label: {
                                    Text(example.name)
                                    Text(verbatim: example.query)
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        Button("Preview on GitHub") { filter.webURL.map(system.open) }
                            .disabled(filter.query.allSatisfy(\.isWhitespace))
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
                    onSave(filter)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!filter.isComplete)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
    }
}

struct RunTabEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ActionsModel.self) private var actions
    @State var tab: RunTab
    let login: String
    let onSave: (RunTab) -> Void

    private var seen: [WorkflowRun] { actions.store.runs(for: login) }

    private var repos: [String] {
        var known = Set<String>()
        return seen.map(\.repo).filter { known.insert($0.lowercased()).inserted }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $tab.name, prompt: Text("Production deploys"))
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
                            "Matches \(seen.filter { tab.includes($0, login: login) }.count) of the \(seen.count) runs Pullo sees right now."
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
