import AppKit
import SwiftUI

/// popover 内的最近截图缩略图模型。
struct PopoverThumbnail: Identifiable, Equatable {
    let id: UUID
    let image: NSImage
    let isAnnotated: Bool
}

/// 设置区里的一行快捷键。
struct HotKeyShortcutRow: Identifiable, Equatable {
    let action: HotKeyAction
    let mapping: HotKeyMapping

    var id: String { action.rawValue }
}

/// popover 的状态与动作。由 `MenuBarController` 注入真实依赖。
@MainActor
final class MenuBarPopoverModel: ObservableObject {
    @Published var permissionGranted = false
    @Published var thumbnails: [PopoverThumbnail] = []
    @Published var imageFormat: ImageFormat = .png
    @Published var saveDirectoryPath: String = ""
    @Published var launchAtLogin = false
    @Published var launchAtLoginNeedsApproval = false
    @Published var showsSettings = false
    @Published var errorMessage: String?
    @Published var shortcutRows: [HotKeyShortcutRow] = []
    @Published var captureShortcutDisplay: String = HotKeyMapping.commandShift2.displayString
    @Published var uploadEndpoint = ""
    @Published var uploadFieldName = "file"
    @Published var uploadAuthorization = ""
    @Published var uploadConfigured = false

    var onCopy: ((UUID) -> Void)?
    var onRevealInFinder: ((UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onClearAll: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    var onScrollCapture: (() -> Void)?
    var onOpenPermissionSettings: (() -> Void)?
    var onChooseDirectory: (() -> Void)?
    var onChangeFormat: ((ImageFormat) -> Void)?
    var onRecordHotKey: ((HotKeyAction, HotKeyMapping?) -> Void)?
    var onUploadEndpointChange: ((String) -> Void)?
    var onUploadFieldNameChange: ((String) -> Void)?
    var onUploadAuthorizationChange: ((String) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
    var onRefresh: (() -> Void)?

    func refresh() {
        onRefresh?()
    }
}

/// popover 的 SwiftUI 内容。
struct MenuBarPopoverView: View {
    @ObservedObject var model: MenuBarPopoverModel

    private let gridColumns = Array(repeating: GridItem(.fixed(64), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            thumbnailsGrid
            Divider()
            actionRow
            if model.showsSettings {
                Divider()
                settingsSection
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { model.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.permissionGranted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(model.permissionGranted ? "屏幕录制权限正常" : "未获得屏幕录制权限")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            if !model.permissionGranted {
                Button("去授权") { model.onOpenPermissionSettings?() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
        }
    }

    private var thumbnailsGrid: some View {
        Group {
            if model.thumbnails.isEmpty {
                Text(String(localized: "还没有截图，按 \(model.captureShortcutDisplay) 开始"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(model.thumbnails) { thumb in
                        Button {
                            model.onCopy?(thumb.id)
                        } label: {
                            Image(nsImage: thumb.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(alignment: .topTrailing) {
                                    if thumb.isAnnotated {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(3)
                                            .background(.black.opacity(0.55))
                                            .foregroundStyle(.white)
                                            .clipShape(Circle())
                                            .padding(3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help("点击复制")
                        .contextMenu {
                            Button("复制") { model.onCopy?(thumb.id) }
                            Button("在 Finder 显示") { model.onRevealInFinder?(thumb.id) }
                            Divider()
                            Button("删除", role: .destructive) { model.onDelete?(thumb.id) }
                        }
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(String(localized: "历史")) { model.onOpenHistory?() }
            Button(String(localized: "长截图")) { model.onScrollCapture?() }
                .help(String(localized: "框选可滚动区域"))
            Button(model.showsSettings ? "收起设置" : "设置") {
                model.showsSettings.toggle()
            }
            Spacer()
            Button("退出") { model.onQuit?() }
        }
        .font(.system(size: 12))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷键")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            ForEach(model.shortcutRows) { row in
                HStack {
                    Text(row.action.title)
                        .font(.system(size: 11))
                    Spacer()
                    ShortcutRecorder(mapping: row.mapping) { newMapping in
                        model.onRecordHotKey?(row.action, newMapping)
                    }
                }
            }
            Text("上传")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack {
                Text("端点")
                    .font(.system(size: 11))
                TextField("https://example.com/upload", text: Binding(
                    get: { model.uploadEndpoint },
                    set: { model.onUploadEndpointChange?($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            }
            HStack {
                Text("字段名")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("file", text: Binding(
                    get: { model.uploadFieldName },
                    set: { model.onUploadFieldNameChange?($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 90)
                Spacer()
            }
            SecureField("鉴权头（可选，如 Bearer …）", text: Binding(
                get: { model.uploadAuthorization },
                set: { model.onUploadAuthorizationChange?($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))
            Text(model.uploadConfigured ? "上传成功后链接自动复制到剪贴板" : "未配置时历史窗口的上传入口隐藏")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack {
                Text("保存到")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(model.saveDirectoryPath)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("选择…") { model.onChooseDirectory?() }
                    .font(.system(size: 11))
            }
            HStack {
                Text("格式")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { model.imageFormat },
                    set: { model.onChangeFormat?($0) }
                )) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            Toggle("登录时自动启动", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.onToggleLaunchAtLogin?($0) }
            ))
            .font(.system(size: 11))
            if model.launchAtLoginNeedsApproval {
                Text("系统设置中已关闭 Cap 登录项，请在「登录项」中重新允许")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("清空历史…") { model.onClearAll?() }
                    .font(.system(size: 11))
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }
}
