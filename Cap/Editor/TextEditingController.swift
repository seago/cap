import AppKit

/// 文字工具的就地输入：在画布上叠一个无边框 NSTextField。
///
/// - Enter 提交，Esc 取消。
/// - 使用系统输入法（NSTextField 原生支持中文 IME）。
/// - 提交时的坐标是**原图像素坐标**，字号也是像素字号。
@MainActor
final class TextEditingController: NSObject, NSTextFieldDelegate {
    private(set) var textField: NSTextField?
    private(set) var isEditing = false

    private var imageOrigin: CGPoint = .zero
    private var fontSize: CGFloat = 22

    /// 提交：文字、像素坐标、像素字号。
    var onCommit: ((String, CGPoint, CGFloat) -> Void)?
    var onCancel: (() -> Void)?

    /// 开始输入。
    /// - Parameters:
    ///   - canvas: 画布视图
    ///   - viewPoint: 输入框左上角（视图坐标）
    ///   - imagePoint: 对应的原图像素坐标
    func begin(
        in canvas: NSView,
        atViewPoint viewPoint: CGPoint,
        imagePoint: CGPoint,
        fontSize: CGFloat,
        color: NSColor
    ) {
        endEditingWithoutCallback()

        self.imageOrigin = imagePoint
        self.fontSize = fontSize

        let height = fontSize + 10
        let field = NSTextField(frame: CGRect(x: viewPoint.x, y: viewPoint.y, width: 220, height: height))
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = color
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderString = "输入文字"
        field.delegate = self

        canvas.addSubview(field)
        textField = field
        isEditing = true
        canvas.window?.makeFirstResponder(field)
    }

    /// 提交当前文字；空白不产生标注。
    func commit() {
        guard let field = textField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        finish()
        guard !text.isEmpty else {
            onCancel?()
            return
        }
        onCommit?(text, imageOrigin, fontSize)
    }

    /// 取消输入。
    func cancel() {
        finish()
        onCancel?()
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            commit()
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            cancel()
            return true
        }
        return false
    }

    // MARK: - 内部

    private func finish() {
        textField?.removeFromSuperview()
        textField = nil
        isEditing = false
    }

    private func endEditingWithoutCallback() {
        guard isEditing else { return }
        finish()
    }
}
