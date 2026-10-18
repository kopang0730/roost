import SwiftUI

// MARK: - FFlag 预设模型

struct PresetOption: Identifiable {
    let label: String
    let labelEN: String
    let set: [String: String]
    var id: String { label }
    var text: String { L.lang == "en" ? labelEN : label }
}

struct PresetItem: Identifiable {
    let id: String
    let kind: String            // select | toggle | number
    let label: String
    let labelEN: String
    let desc: String
    let descEN: String
    let keys: [String]
    let set: [String: String]
    let options: [PresetOption]

    var text: String { L.lang == "en" ? labelEN : label }
    var subtitle: String { L.lang == "en" ? descEN : desc }
}

struct PresetGroup: Identifiable {
    let title: String
    let titleEN: String
    let items: [PresetItem]
    var id: String { title }
    var text: String { L.lang == "en" ? titleEN : title }
}

enum PresetDecode {
    static func groups(_ raw: [[String: Any]]) -> [PresetGroup] {
        raw.compactMap { g in
            guard let title = g["title"] as? String,
                  let items = g["items"] as? [[String: Any]] else { return nil }
            let titleEN = (g["title_en"] as? String) ?? title
            return PresetGroup(title: title, titleEN: titleEN, items: items.compactMap(item))
        }
    }

    private static func item(_ j: [String: Any]) -> PresetItem? {
        guard let label = j["label"] as? String else { return nil }
        let set = (j["set"] as? [String: String]) ?? [:]
        let keys = (j["keys"] as? [String]) ?? Array(set.keys)
        let opts = (j["options"] as? [[String: Any]])?.map { o -> PresetOption in
            let l = o["label"] as? String ?? ""
            return PresetOption(label: l,
                                labelEN: (o["label_en"] as? String) ?? l,
                                set: (o["set"] as? [String: String]) ?? [:])
        } ?? []
        return PresetItem(id: (j["id"] as? String) ?? label,
                          kind: (j["kind"] as? String) ?? "toggle",
                          label: label,
                          labelEN: (j["label_en"] as? String) ?? label,
                          desc: (j["desc"] as? String) ?? "",
                          descEN: (j["desc_en"] as? String) ?? ((j["desc"] as? String) ?? ""),
                          keys: keys,
                          set: set,
                          options: opts)
    }
}

// MARK: - 推荐设置面板

struct PresetSection: View {
    @EnvironmentObject var store: Store
    let account: Account
    @State private var numbers: [String: String] = [:]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(L.t("推荐设置", "Recommended settings")).font(.headline)
                    Text(L.t("勾选就生效，不用记 Flag 名", "Applies instantly — no flag names to remember")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L.t("性能优先", "Performance")) { store.applyPerf(account.name) }
                        .help(Text(L.t("一键套用最省性能的组合", "Apply the fastest combination")))
                        .hoverHint(L.t("一键套用：最低纹理 + Voxel 光照 + 最低画质 + 灰天空 + 去草", "Apply: lowest textures + Voxel lighting + lowest quality + gray sky + no grass"), store)
                        .disabled(store.busy != nil)
                        .help(L.t("一键：最低纹理 + Voxel 光照 + 最低画质 + 灰天空 + 去草 + 关抗锯齿", "One click: lowest textures + Voxel lighting + lowest quality + gray sky + no grass + no MSAA"))
                    Button(L.t("恢复默认", "Reset")) { store.resetFlags(account.name) }
                        .help(Text(L.t("清掉所有预设管理的 Flag", "Clear every preset-managed flag")))
                        .hoverHint(L.t("把下面所有预设项恢复成默认（不影响手写的 Flag）", "Reset every preset below to default (raw flags are kept)"), store)
                        .disabled(store.busy != nil)
                        .help(L.t("清掉下面所有预设管理的 Flag", "Clear all preset-managed flags"))
                }

                if store.presetGroups.isEmpty {
                    Text(L.t("预设加载中…", "Loading presets…")).font(.caption).foregroundStyle(.secondary)
                }

                ForEach(store.presetGroups) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(group.text)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        ForEach(group.items) { item in
                            row(item)
                            if item.id != group.items.last?.id { Divider().opacity(0.4) }
                        }
                    }
                }
            }
            .padding(6)
        }
        .disabled(store.busy != nil)
        .onAppear { syncNumbers() }
        .onChange(of: account.flags) { _ in syncNumbers() }
    }

    // MARK: 单行

    @ViewBuilder
    private func row(_ item: PresetItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text).font(.system(size: 13, weight: .medium))
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)

            switch item.kind {
            case "select":
                Picker("", selection: selectionBinding(item)) {
                    ForEach(Array(item.options.enumerated()), id: \.offset) { idx, opt in
                        Text(opt.text).tag(idx)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)

            case "number":
                TextField(L.t("默认", "Default"), text: Binding(
                    get: { numbers[item.id] ?? "" },
                    set: { numbers[item.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 100)
                .onSubmit { applyNumber(item) }

            default:
                Toggle("", isOn: toggleBinding(item))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    // MARK: 绑定

    private func selectionBinding(_ item: PresetItem) -> Binding<Int> {
        Binding(
            get: {
                for (i, o) in item.options.enumerated() {
                    if item.keys.allSatisfy({ o.set[$0] == account.flags[$0] }) { return i }
                }
                return 0
            },
            set: { idx in
                guard idx < item.options.count else { return }
                var flags = account.flags
                for k in item.keys { flags.removeValue(forKey: k) }
                flags.merge(item.options[idx].set) { _, new in new }
                store.saveFlags(account.name, flags)
            }
        )
    }

    private func toggleBinding(_ item: PresetItem) -> Binding<Bool> {
        Binding(
            get: { item.set.allSatisfy { account.flags[$0.key] == $0.value } },
            set: { on in
                var flags = account.flags
                for k in item.set.keys { flags.removeValue(forKey: k) }
                if on { flags.merge(item.set) { _, new in new } }
                store.saveFlags(account.name, flags)
            }
        )
    }

    private func applyNumber(_ item: PresetItem) {
        guard let key = item.keys.first else { return }
        let raw = (numbers[item.id] ?? "").trimmingCharacters(in: .whitespaces)
        var flags = account.flags
        flags.removeValue(forKey: key)
        if !raw.isEmpty { flags[key] = raw }
        store.saveFlags(account.name, flags)
    }

    private func syncNumbers() {
        for g in store.presetGroups {
            for item in g.items where item.kind == "number" {
                if let key = item.keys.first {
                    numbers[item.id] = account.flags[key] ?? ""
                }
            }
        }
    }
}

// MARK: - 高级：手写 FFlags

struct RawFlagsEditor: View {
    @EnvironmentObject var store: Store
    let account: Account
    @State private var rows: [FlagRow] = []

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: Binding(
                get: { expanded },
                set: { expanded = $0 }
            )) {
                VStack(alignment: .leading, spacing: 10) {
                    if rows.isEmpty {
                        Text(L.t("没有额外的 FFlags。", "No extra FFlags.")).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($rows) { $row in
                        HStack(spacing: 8) {
                            TextField(L.t("Flag 名", "Flag name"), text: $row.key)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                            TextField(L.t("值", "Value"), text: $row.value)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 140)
                            Button {
                                rows.removeAll { $0.id == row.id }
                            } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button {
                            rows.append(FlagRow(key: "", value: ""))
                        } label: { Label(L.t("新增", "Add"), systemImage: "plus") }
                        Spacer()
                        Button(L.t("保存", "Save")) {
                            var dict: [String: String] = [:]
                            for r in rows where !r.key.trimmingCharacters(in: .whitespaces).isEmpty {
                                dict[r.key.trimmingCharacters(in: .whitespaces)] = r.value
                            }
                            store.saveFlags(account.name, dict)
                        }
                        .disabled(store.busy != nil)
                    }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("高级：手写 FFlags", "Advanced: raw FFlags")).font(.headline)
                    Text(L.t("上面预设没覆盖的键可以在这里加；保存会覆盖当前全部 Flag。", "Add keys the presets don't cover. Saving overwrites all current flags."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { sync() }
        .onChange(of: account.flags) { _ in sync() }
    }

    @State private var expanded = false

    private func sync() {
        rows = account.flags.sorted { $0.key < $1.key }.map { FlagRow(key: $0.key, value: $0.value) }
    }
}
