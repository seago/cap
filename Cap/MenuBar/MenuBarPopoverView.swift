import AppKit
import SwiftUI

/// popover 内的最近截图缩略图模型。
struct PopoverThumbnail: Identifiable, Equatable {
    let id: UUID
    let image: NSImage
    let isAnnotated: Bool
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

    var onCopy: ((UUID) -> Void)?
    var onRevealInFinder: ((UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onClearAll: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    var onOpenPermissionSettings: (() -> Void)?
    var onChooseDirectory: (() -> Void)?
    var onChangeFormat: ((ImageFormat) -> Void)?
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
                Text("还没有截图，按 ⌘⇧2 开始")
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
            Button("全部截图") { model.onOpenHistory?() }
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
