#if canImport(UIKit) && canImport(WebKit)
import UIKit

/// A round chat button with the unread badge, ready to put on any screen. Tapping it
/// opens the chat.
///
/// ```swift
/// let button = LiveChatAEButton()
/// view.addSubview(button)   // 60×60 points by default
/// ```
@MainActor
public final class LiveChatAEButton: UIButton {
    private let badge = UILabel()

    /// Color of the button. Default: the app's tint color.
    public var color: UIColor? {
        didSet { backgroundColor = color ?? tintColor }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame == .zero ? CGRect(x: 0, y: 0, width: 60, height: 60) : frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    public override var intrinsicContentSize: CGSize { CGSize(width: 60, height: 60) }

    private func setUp() {
        backgroundColor = tintColor
        let image = UIImage(systemName: "bubble.left.and.bubble.right.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        setImage(image, for: .normal)
        imageView?.tintColor = .white
        tintAdjustmentMode = .normal
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        accessibilityLabel = NSLocalizedString("Chat", comment: "")

        badge.backgroundColor = .systemRed
        badge.textColor = .white
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.layer.masksToBounds = true
        badge.isHidden = true
        badge.isAccessibilityElement = false
        addSubview(badge)

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(unreadChanged),
                                               name: LiveChatAE.unreadCountDidChangeNotification, object: nil)
        update(count: LiveChatAE.unreadCount)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        let w = max(20, badge.intrinsicContentSize.width + 10)
        badge.frame = CGRect(x: bounds.width - w + 4, y: -4, width: w, height: 20)
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()
        if color == nil { backgroundColor = tintColor }
    }

    @objc private func tapped() {
        LiveChatAE.present(from: nearestViewController())
    }

    @objc private func unreadChanged(_ n: Notification) {
        update(count: n.object as? Int ?? LiveChatAE.unreadCount)
    }

    private func update(count: Int) {
        badge.text = count > 99 ? "99+" : "\(count)"
        badge.isHidden = count == 0
        accessibilityValue = count > 0 ? "\(count)" : nil
        setNeedsLayout()
    }

    private func nearestViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let next = r?.next {
            if let vc = next as? UIViewController { return vc }
            r = next
        }
        return nil
    }
}
#endif

#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import SwiftUI

/// The chat button for SwiftUI, with the unread badge.
///
/// ```swift
/// .overlay(alignment: .bottomTrailing) { LiveChatAEChatButton().padding() }
/// ```
@MainActor
public struct LiveChatAEChatButton: View {
    @ObservedObject private var state = LiveChatAEState.shared
    private let color: Color?

    public init(color: Color? = nil) {
        self.color = color
    }

    public var body: some View {
        Button {
            LiveChatAE.present()
        } label: {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(color ?? Color.accentColor))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                .overlay(alignment: .topTrailing) {
                    if state.unreadCount > 0 {
                        Text(state.unreadCount > 99 ? "99+" : "\(state.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Chat"))
        .accessibilityValue(state.unreadCount > 0 ? Text("\(state.unreadCount)") : Text(""))
    }
}
#endif
