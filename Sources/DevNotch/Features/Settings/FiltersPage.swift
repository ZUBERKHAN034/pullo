import AppKit
import SwiftUI

struct FiltersPage: View {
    @Environment(AccountStore.self) private var accounts
    @State private var chosenLogin: String?
    @State private var editing: SavedFilter?

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
                filtersSection(for: login)
            } else {
                Text("Add an account first.").foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editing) { filter in
            FilterEditor(filter: filter) { saved in
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
    }

    private func filtersSection(for login: String) -> some View {
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
                Button("Add tab…") { editing = SavedFilter(name: "", query: "") }
                Spacer()
                if !missingPresets.isEmpty {
                    Button("Restore default tabs") {
                        accounts.setFilters(missingPresets.map { SavedFilter.builtIn($0) } + filters, for: login)
                    }
                }
            }
        } header: {
            Text("Tabs for @\(login)")
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

private struct FilterEditor: View {
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
                    TextField("Search", text: $filter.query, prompt: Text(verbatim: "repo:acme/api label:bug"), axis: .vertical)
                        .labelsHidden()
                        .font(.body.monospaced())
                        .lineLimit(2...4)
                } header: {
                    Text("Search")
                } footer: {
                    HStack {
                        Link(
                            "Search syntax",
                            destination: URL(
                                static: "https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests"
                            )
                        )
                        Spacer()
                        Button("Preview on GitHub") { filter.webURL.map(system.open) }
                            .disabled(filter.query.trimmingCharacters(in: .whitespaces).isEmpty)
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
