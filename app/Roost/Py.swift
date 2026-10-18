import Foundation

// MARK: - 数据模型

struct Account: Identifiable, Hashable {
    let name: String
    var userID: Int?
    var username: String?
    var displayName: String?
    var flags: [String: String]
    var instanceReady: Bool
    var place: String?
    var size: String?
    var fps: String?

    var id: String { name }

    init?(json: [String: Any]) {
        guard let n = json["name"] as? String else { return nil }
        name = n
        userID = json["user_id"] as? Int
        username = json["username"] as? String
        displayName = json["display_name"] as? String
        flags = (json["flags"] as? [String: String]) ?? [:]
        instanceReady = (json["instance_ready"] as? Bool) ?? false
        let prefs = (json["prefs"] as? [String: Any]) ?? [:]
        place = prefs["place"] as? String
        size = prefs["size"] as? String
        fps = prefs["fps"] as? String
    }

    var uidText: String { userID.map { "u\($0)" } ?? "u?" }
}

struct Status {
    var robloxVersion: String = "?"
    var robloxInstalled: Bool = false
    var localSession: Bool = false
    var localSessionLen: Int = 0
    var clang: Bool = false
    var cookieWriter: Bool = false
}

// MARK: - 调 epmulti 的 JSON API

enum Py {
    /// 优先用 app 包里的脚本，方便整体拷走；找不到再退回开发路径。
    static var scriptPath: String {
        if let res = Bundle.main.resourceURL {
            let p = res.appendingPathComponent("roost").path
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        // 开发模式：用 ROOST_CLI 指向仓库里的 roost
        return ProcessInfo.processInfo.environment["ROOST_CLI"] ?? ""
    }

    /// 优先用 app 内置的 Python（朋友机器上不需要装命令行工具）
    static var pythonPath: String {
        if let res = Bundle.main.resourceURL {
            let p = res.appendingPathComponent("python/bin/python3").path
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return "/usr/bin/python3"
    }

    static func shellPath() -> String {
        let candidates = [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
            "/usr/sbin", "/sbin",
            "/Library/Developer/CommandLineTools/usr/bin",
        ]
        return candidates.joined(separator: ":")
    }

    /// 同步调用，必须在后台线程执行。
    static func call(_ verb: String,
                     _ args: [String: Any] = [:],
                     onLog: @escaping (String) -> Void) -> [String: Any] {
        guard !scriptPath.isEmpty else {
            return ["ok": false, "error": "CLI not found (set ROOST_CLI)"]
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath, "api", verb]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = shellPath()
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1" // Keep the signed app bundle immutable.
        env["ROOST_LANG"] = L.lang
        proc.environment = env

        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do { try proc.run() } catch {
            return ["ok": false, "error": L.t("无法启动 python3: \(error.localizedDescription)", "Cannot start python3: \(error.localizedDescription)")]
        }

        if let data = try? JSONSerialization.data(withJSONObject: args), !args.isEmpty {
            inPipe.fileHandleForWriting.write(data)
        }
        try? inPipe.fileHandleForWriting.close()

        // stderr 逐行流到日志
        let errHandle = errPipe.fileHandleForReading
        let queue = DispatchQueue(label: "roost.stderr")
        queue.async {
            var buffer = Data()
            while true {
                let chunk = errHandle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                    buffer.removeSubrange(buffer.startIndex...nl)
                    if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                        DispatchQueue.main.async { onLog(line) }
                    }
                }
            }
            if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async { onLog(line) }
            }
        }

        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard let obj = try? JSONSerialization.jsonObject(with: out) as? [String: Any] else {
            let raw = String(data: out, encoding: .utf8) ?? ""
            return ["ok": false, "error": L.t("返回不是 JSON: \(raw.prefix(200))", "Response is not JSON: \(raw.prefix(200))")]
        }
        return obj
    }
}
