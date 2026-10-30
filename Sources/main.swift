import AppKit
import SwiftUI
import SQLite3

struct LogEntry: Identifiable {
    let id: String
    let endpoint: String
    let agent: String
    let rule: String
    let kind: String
    let created: String
    var label: String {
        switch kind.uppercased() {
        case "PROXY": return "代理 · PROXY"
        case "DIRECT": return "直连 · DIRECT"
        case "REJECT", "REJECT-DROP": return "拦截 · \(kind)"
        default: return kind.isEmpty ? "日志未标记" : kind
        }
    }
    var color: Color {
        switch kind.uppercased() {
        case "PROXY": return .blue
        case "DIRECT": return .green
        case "REJECT", "REJECT-DROP": return .red
        default: return .secondary
        }
    }
}

let defaultLogFolder = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/group.com.liguangming.Shadowrocket/Library/Caches/Logs")

struct LogError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func latestDatabase(in folder: URL) throws -> URL? {
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    return files.filter { $0.lastPathComponent.hasPrefix("proxy-") && $0.pathExtension == "db" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }.first
}

func readLog(_ file: URL) throws -> [LogEntry] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(file.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
    guard status == SQLITE_OK, let db = database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
        if let db = database { sqlite3_close(db) }
        throw LogError(message: "日志读取失败：\(detail)。可使用“选择日志目录”重新指定小火箭 Logs 目录。")
    }
    defer { sqlite3_close(db) }
    guard sqlite3_db_readonly(db, "main") == 1 else { throw LogError(message: "拒绝以可写方式打开日志。") }
    sqlite3_busy_timeout(db, 800)
    var statement: OpaquePointer?
    let sql = "SELECT rowid,url,ua,result,type,created FROM logging ORDER BY rowid DESC LIMIT 500"
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        throw LogError(message: "小火箭日志格式不兼容：\(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(statement) }
    var entries: [LogEntry] = []
    func string(_ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }
    while true {
        let step = sqlite3_step(statement)
        if step == SQLITE_DONE { break }
        guard step == SQLITE_ROW else { throw LogError(message: "日志正在更新或无法读取：\(String(cString: sqlite3_errmsg(db)))") }
        entries.append(LogEntry(id: "\(file.lastPathComponent):\(sqlite3_column_int64(statement, 0))",
                                endpoint: string(1), agent: string(2), rule: string(3), kind: string(4), created: string(5)))
    }
    return entries
}

final class Monitor: ObservableObject {
    @Published var entries: [LogEntry] = []
    @Published var status = "正在读取小火箭日志…"
    @Published var filename = ""
    @Published var updated = ""
    @Published var folder: URL
    private let queue = DispatchQueue(label: "RocketLog.shadowrocket.logs", qos: .utility)
    private var timer: Timer?
    private var reading = false
    var onTitle: ((String) -> Void)?

    init() {
        if let saved = UserDefaults.standard.string(forKey: "shadowrocketLogFolder") {
            folder = URL(fileURLWithPath: saved, isDirectory: true)
        } else { folder = defaultLogFolder }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard !reading else { return }
        reading = true
        let selected = folder
        queue.async {
            let result: Result<(URL?, [LogEntry]), Error> = Result {
                guard let file = try latestDatabase(in: selected) else { return (nil, []) }
                return (file, try readLog(file))
            }
            DispatchQueue.main.async {
                self.reading = false
                guard self.folder == selected else { self.refresh(); return }
                self.updated = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                switch result {
                case .success(let (file, rows)):
                    self.entries = rows
                    self.filename = file?.lastPathComponent ?? "未找到 proxy-*.db"
                    self.status = file == nil ? "暂无连接日志。请在小火箭中开启连接记录，或选择正确的日志目录。" : rows.isEmpty ? "日志已连接，尚无记录。" : "已连接小火箭日志 · 每 2 秒读取 · 最新记录优先"
                    let kind = rows.first?.kind.uppercased() ?? ""
                    self.onTitle?(rows.isEmpty ? "RocketLog · 等待日志" : "RocketLog · \(kind.isEmpty ? "日志" : kind)")
                case .failure(let error):
                    self.entries = []; self.filename = ""
                    self.status = error.localizedDescription
                    self.onTitle?("RocketLog · 日志不可用")
                }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择小火箭连接日志目录"
        panel.message = "请选择包含 proxy-*.db 的 Logs 目录。只读取日志，不修改小火箭文件。"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.directoryURL = folder
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let selected = panel.url {
            folder = selected
            UserDefaults.standard.set(selected.path, forKey: "shadowrocketLogFolder")
            entries = []; filename = ""; status = "正在切换日志目录…"
            refresh()
        }
    }
}

struct Panel: View {
    @ObservedObject var model: Monitor
    @State private var search = ""
    @State private var filter = "全部"
    var rows: [LogEntry] {
        model.entries.filter { entry in
            (filter == "全部" || entry.kind.uppercased() == filter || (filter == "REJECT" && entry.kind.uppercased().hasPrefix("REJECT-"))) &&
            (search.isEmpty || "\(entry.endpoint) \(entry.agent) \(entry.rule) \(entry.kind) \(entry.created)".localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RocketLog · 小火箭日志").font(.title2.bold())
                Spacer()
                Button("刷新") { model.refresh() }
                Button("退出") { NSApp.terminate(nil) }
            }
            HStack(spacing: 24) {
                count("代理", model.entries.filter { $0.kind.uppercased() == "PROXY" }.count, .blue)
                count("直连", model.entries.filter { $0.kind.uppercased() == "DIRECT" }.count, .green)
                count("其他", model.entries.filter { !["PROXY", "DIRECT"].contains($0.kind.uppercased()) }.count, .secondary)
                Spacer()
                Text("最近 \(model.entries.count) 条\n检查时间 \(model.updated)").font(.caption).foregroundColor(.secondary)
            }.padding(12).background(Color.primary.opacity(0.04)).cornerRadius(10)
            Text(model.status).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("搜索域名、IP、节点或匹配规则", text: $search)
                Picker("结果", selection: $filter) {
                    Text("全部").tag("全部")
                    Text("代理").tag("PROXY")
                    Text("直连").tag("DIRECT")
                    Text("拦截").tag("REJECT")
                }.labelsHidden().frame(width: 105)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if rows.isEmpty { Text("暂无匹配的小火箭日志").foregroundColor(.secondary).padding(.vertical, 24) }
                    ForEach(rows) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(entry.endpoint).font(.system(size: 14, weight: .semibold)).textSelection(.enabled)
                                Spacer()
                                Text(entry.label).font(.caption.bold()).foregroundColor(entry.color)
                            }
                            Text(entry.rule.isEmpty ? "日志没有提供匹配规则" : entry.rule)
                                .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            HStack {
                                Text(entry.created)
                                Spacer()
                                Text(entry.agent).lineLimit(1).truncationMode(.tail).frame(maxWidth: 340, alignment: .trailing).help(entry.agent)
                            }.font(.system(size: 10)).foregroundColor(.secondary)
                        }.padding(.vertical, 11)
                        Divider()
                    }
                }
            }
            HStack {
                Text(model.filename).lineLimit(1).truncationMode(.middle).help(model.folder.path)
                Spacer()
                Button("选择日志目录") { model.chooseFolder() }
            }.font(.caption).foregroundColor(.secondary)
            Text("只读小火箭最新会话的最近 500 条连接日志。DIRECT / PROXY 为日志原始结果。\n这些是历史连接记录，不是当前活动连接；日志无新记录时列表保持不变。\n该日志不含上下行字节或域名对应的实际 IP，不额外抓包、测速或查询 DNS。")
                .font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(width: 680, height: 650)
    }
    func count(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("\(value)").font(.system(size: 24, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }
    }
}
final class HoverView: NSView {
    var enter: (() -> Void)?
    var leave: (() -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { enter?() }
    override func mouseExited(with event: NSEvent) { leave?() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class Delegate: NSObject, NSApplicationDelegate {
    let model = Monitor()
    let popover = NSPopover()
    var item: NSStatusItem!
    var hover: HoverView!
    var closeTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.title = "RocketLog"
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.target = self; button.action = #selector(toggle)
        button.toolTip = "悬停查看小火箭日志；点击展开或收起"
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Panel(model: model))
        hover = HoverView(frame: button.bounds)
        hover.autoresizingMask = [.width, .height]
        hover.enter = { [weak self] in self?.show() }
        hover.leave = { [weak self] in self?.scheduleClose() }
        button.addSubview(hover)
        model.onTitle = { [weak self] title in self?.item.button?.title = title }
        DispatchQueue.main.async { [weak self] in self?.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return true
    }
    @objc func toggle() {
        closeTimer?.invalidate()
        if popover.isShown { popover.performClose(nil) } else { show() }
    }
    func show() {
        closeTimer?.invalidate()
        guard !popover.isShown, let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    func scheduleClose() {
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let point = NSEvent.mouseLocation
            if let window = self.popover.contentViewController?.view.window, window.frame.insetBy(dx: -8, dy: -8).contains(point) { return }
            if let button = self.item.button, let window = button.window,
               window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) { return }
            self.popover.performClose(nil); timer.invalidate()
        }
    }
}

func require(_ condition: Bool, line: Int = #line) {
    if !condition { fputs("Self-test failed at line \(line)\n", stderr); exit(1) }
}

if CommandLine.arguments.contains("--self-test") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("proxy-2026-10-30-120000.db")
    var fixture: OpaquePointer?
    require(sqlite3_open(file.path, &fixture) == SQLITE_OK)
    require(sqlite3_exec(fixture, "CREATE VIRTUAL TABLE logging USING fts3(url,ua,result,type,created); INSERT INTO logging VALUES('old.example:443','TCP Stream','FINAL,PROXY # node','PROXY','2026-10-30 12:00:00'); INSERT INTO logging VALUES('new.example:443','TCP Stream','GEOIP,CN,DIRECT','DIRECT','2026-10-30 12:00:01');", nil, nil, nil) == SQLITE_OK)
    sqlite3_close(fixture)
    let rows = try readLog(file)
    require(rows.count == 2 && rows[0].endpoint == "new.example:443")
    require(rows[0].label == "直连 · DIRECT" && rows[1].label == "代理 · PROXY")
    let discovered = try latestDatabase(in: directory)
    require(discovered?.standardizedFileURL.path == file.standardizedFileURL.path)
    let before = try Data(contentsOf: file)
    _ = try readLog(file)
    let after = try Data(contentsOf: file)
    require(before == after)
    print("PASS: Shadowrocket FTS3 schema, newest-first ordering, original rule/result, read-only file integrity, log discovery")
} else if CommandLine.arguments.contains("--diagnose") {
    do {
        guard let file = try latestDatabase(in: defaultLogFolder) else { throw LogError(message: "未找到小火箭日志") }
        let rows = try readLog(file)
        print("Source: \(file.lastPathComponent)")
        print("Recent records: \(rows.count); PROXY: \(rows.filter { $0.kind == "PROXY" }.count); DIRECT: \(rows.filter { $0.kind == "DIRECT" }.count)")
        print("Latest log time: \(rows.first?.created ?? "none")")
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = Delegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
