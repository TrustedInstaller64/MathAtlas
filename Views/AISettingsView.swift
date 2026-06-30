import SwiftUI
import Network

struct AISettingsView: View {
    @State private var apiKey: String = ""
    @State private var provider: AIProvider = .cloud
    @State private var ollamaModel: String = "deepseek-r1:7b"
    @State private var ollamaEndpoint: String = "http://localhost:11434"

    @AppStorage("cloudModel") private var cloudModel: String = "deepseek-v4-flash"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.deepseek.com"
    @AppStorage("thinkingEnabled") private var thinkingEnabled: Bool = false
    @AppStorage("thinkingDepth") private var thinkingDepth: String = "medium"
    @AppStorage("aiProvider") private var aiProviderRaw: String = "cloud"

    private var aiProvider: AIProvider {
        get { AIProvider(rawValue: aiProviderRaw) ?? .cloud }
        set { aiProviderRaw = newValue.rawValue }
    }

    // AI enabled
    @AppStorage("aiEnabled") private var aiEnabled: Bool = true

    // Prompt management
    @State private var promptPath: String = ""
    @State private var showMovePromptAlert = false
    @State private var pendingPromptPath: String = ""

    // Connection tests
    @State private var tcpResult: String?
    @State private var apiResult: String?
    @State private var isTCPing = false
    @State private var isAPITesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Enable toggle
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("启用 AI 辅助功能", isOn: $aiEnabled)
                        .font(.system(size: 13, weight: .semibold))
                    Text("关闭后所有 AI 相关功能将隐藏，API 请求不会发出。")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }

                Divider()

                // Provider
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 服务").font(.system(size: 13, weight: .semibold))
                    Picker("", selection: $provider) {
                        ForEach(AIProvider.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                    }.pickerStyle(.segmented).frame(width: 260)
                }

                // API Key (cloud only)
                if provider == .cloud {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key").font(.system(size: 13, weight: .semibold))
                        HStack {
                            SecureField("输入 DeepSeek API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            Button("保存") { _ = KeychainManager.saveAPIKey(apiKey) }
                                .buttonStyle(.bordered)
                        }
                        Text("API Key 安全存储在 macOS 钥匙串中")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Endpoint").font(.system(size: 13, weight: .semibold))
                        TextField("Endpoint URL", text: $cloudEndpoint).textFieldStyle(.roundedBorder)
                    }
                }

                // Ollama endpoint
                if provider == .ollama {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ollama Endpoint").font(.system(size: 13, weight: .semibold))
                        TextField("http://localhost:11434", text: $ollamaEndpoint).textFieldStyle(.roundedBorder)
                        Text("无需 API Key，Ollama 默认监听 localhost:11434")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }

                // Model selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("模型").font(.system(size: 13, weight: .semibold))
                    if provider == .cloud {
                        Picker("", selection: $cloudModel) {
                            Text("DeepSeek V4 Pro（128K 上下文 · 思考深 · 速度适中）").tag("deepseek-v4-pro")
                            Text("DeepSeek V4 Flash（8K 上下文 · 响应快 · 轻量）").tag("deepseek-v4-flash")
                        }.pickerStyle(.radioGroup)
                    } else {
                        TextField("模型名称（如 deepseek-r1:7b）", text: $ollamaModel)
                            .textFieldStyle(.roundedBorder)
                        Text("在终端运行 `ollama list` 查看已安装模型")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }

                if provider == .cloud {
                    Divider()
                    // Thinking mode
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("思考模式", isOn: $thinkingEnabled)
                            .font(.system(size: 13, weight: .semibold))
                        Text("关闭后以 --thinking disabled 启动新会话，仅解析生成和全卷分题使用思考模式。")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                        if thinkingEnabled {
                            Picker("思考深度", selection: $thinkingDepth) {
                                Text("低（快速响应）").tag("low")
                                Text("中（平衡）").tag("medium")
                                Text("高（深度推理）").tag("high")
                            }.pickerStyle(.radioGroup)
                        }
                    }
                }

                Divider()

                // Prompt customization
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 提示词").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 4) {
                        Text(promptPath).font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("更改") { pickPromptDirectory() }.buttonStyle(.bordered).font(.system(size: 10))
                        Button("打开") { NSWorkspace.shared.open(PromptManager.promptDirectory) }
                            .buttonStyle(.bordered).font(.system(size: 10))
                        Button("恢复默认") { try? PromptManager.restoreDefaults() }
                            .buttonStyle(.bordered).font(.system(size: 10))
                    }
                    Text("提示词存储在 JSON 文件中，可通过文本编辑器修改。支持占位符：{problem} {category} {existingTags} {levelGuidance}")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .onAppear { promptPath = PromptManager.promptDirectory.path }
                .alert("移动提示词文件？", isPresented: $showMovePromptAlert) {
                    Button("移动") { movePromptFiles() }
                    Button("不移动", role: .cancel) { commitPromptPath() }
                } message: { Text("将现有提示词文件移动到新位置？") }

                Divider()

                // Connection tests
                VStack(alignment: .leading, spacing: 8) {
                    Text("连接测试").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 8) {
                        testButton("TCP 延迟", result: $tcpResult, loading: $isTCPing) { await testTCP() }
                        testButton("API 验证", result: $apiResult, loading: $isAPITesting) { await testAPI() }
                    }
                    Text("TCP 延迟反映网络链路质量；API 延迟包含 TLS 协商与模型推理开销，1000ms 左右属正常范围。")
                        .font(.system(size: 9)).foregroundColor(.secondary).lineSpacing(2)
                    Button("全部检测") {
                        Task {
                            await testTCP(); await testAPI()
                        }
                    }.buttonStyle(.bordered).font(.system(size: 12))
                }
            }.padding(20)
        }
        .onAppear {
            apiKey = KeychainManager.loadAPIKey() ?? ""
        }
    }

    // MARK: - Tests

    private func testTCP() async {
        isTCPing = true; tcpResult = "检测中..."
        let host = provider == .cloud ? "api.deepseek.com" : "localhost"
        let port: UInt16 = provider == .cloud ? 443 : 11434
        let start = Date()
        let conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let ms = Date().timeIntervalSince(start) * 1000
                DispatchQueue.main.async { tcpResult = "✅ \(String(format: "%.0f", ms))ms"; isTCPing = false }
                conn.cancel()
            case .failed(let err):
                DispatchQueue.main.async { tcpResult = "❌ \(err.localizedDescription)"; isTCPing = false }
                conn.cancel()
            default: break
            }
        }
        conn.start(queue: .main)
        // Timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if isTCPing { isTCPing = false; tcpResult = "❌ 超时" }
        }
    }

    private func testAPI() async {
        isAPITesting = true; apiResult = "检测中..."
        if cloudModel.isEmpty {
            apiResult = "❌ 请先选择模型"; isAPITesting = false; return
        }
        let config = currentConfig()
        let client = DeepSeekClient(config: config)

        do {
            let (ok, latency, model) = try await client.verify()
            let latStr = String(format: "%.0f", latency)
            apiResult = "✅ \(model) · \(latStr)ms"
            let d = UserDefaults.standard
            let ms = latency
            if ms < 1500 { d.set("green", forKey: "aiLight") }
            else if ms < 3000 { d.set("yellow", forKey: "aiLight") }
            else { d.set("red", forKey: "aiLight") }
            d.set(latStr, forKey: "aiLatency")
            d.set(model, forKey: "aiModel")
            d.set(Date().formatted(.dateTime.hour().minute()), forKey: "aiCheckTime")
        } catch let error as AIError {
            apiResult = "❌ \(error.localizedDescription)"
            UserDefaults.standard.set("red", forKey: "aiLight")
        } catch {
            apiResult = "❌ \(error.localizedDescription)"
            UserDefaults.standard.set("red", forKey: "aiLight")
        }
        isAPITesting = false
    }

    private func currentConfig() -> AIConfig {
        AIConfig(
            provider: provider, cloudModel: cloudModel, ollamaModel: ollamaModel,
            cloudEndpoint: cloudEndpoint, ollamaEndpoint: ollamaEndpoint,
            thinkingEnabled: thinkingEnabled, thinkingDepth: thinkingDepth
        )
    }

    // MARK: - Test Button

    private func testButton(_ label: String, result: Binding<String?>, loading: Binding<Bool>,
                            action: @escaping () async -> Void) -> some View {
        VStack(spacing: 4) {
            Button(label) {
                Task { await action() }
            }
            .buttonStyle(.bordered)
            .disabled(loading.wrappedValue)
            .font(.system(size: 12))
            if let r = result.wrappedValue {
                Text(r).font(.system(size: 10)).foregroundColor(r.hasPrefix("✅") ? .green : .red)
            }
            if loading.wrappedValue {
                ProgressView().scaleEffect(0.5)
            }
        }
    }

    private func pickPromptDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.message = "选择提示词存储目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let newPath = url.path
        guard newPath != PromptManager.promptDirectory.path else { return }
        pendingPromptPath = newPath
        // Check if there are prompt files to move
        let oldDir = PromptManager.promptDirectory
        let hasFiles = PromptManager.Key.allCases.contains {
            FileManager.default.fileExists(atPath: oldDir.appendingPathComponent($0.fileName).path)
        }
        if hasFiles { showMovePromptAlert = true }
        else { commitPromptPath() }
    }

    private func movePromptFiles() {
        let oldDir = PromptManager.promptDirectory
        let newDir = URL(fileURLWithPath: pendingPromptPath)
        try? PromptManager.movePrompts(from: oldDir, to: newDir)
        commitPromptPath()
    }

    private func commitPromptPath() {
        PromptManager.promptDirectory = URL(fileURLWithPath: pendingPromptPath)
        promptPath = pendingPromptPath
        // Ensure defaults exist in new location
        PromptManager.ensureDefaultsExist()
    }
}
