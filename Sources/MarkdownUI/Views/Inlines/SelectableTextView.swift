import SwiftUI

#if canImport(UIKit)
import UIKit

/// A selectable text view that wraps UITextView for use in SwiftUI.
/// Supports text selection, copy, and link handling.
@available(iOS 14.0, *)
struct SelectableTextView: UIViewRepresentable {
  let attributedString: NSAttributedString
  let onLinkTap: ((URL) -> Void)?

  init(attributedString: NSAttributedString, onLinkTap: ((URL) -> Void)? = nil) {
    self.attributedString = attributedString
    self.onLinkTap = onLinkTap
  }

  func makeUIView(context: Context) -> SelectableUITextView {
    let textView = SelectableUITextView()
    textView.delegate = context.coordinator
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

    // Set selection/tint color to #FF2882
    textView.tintColor = UIColor(red: 1.0, green: 40.0/255.0, blue: 130.0/255.0, alpha: 1.0)

    // Enable data detection for links if needed
    textView.dataDetectorTypes = []

    return textView
  }

  func updateUIView(_ uiView: SelectableUITextView, context: Context) {
    if uiView.attributedText != attributedString {
      uiView.attributedText = attributedString
      uiView.invalidateIntrinsicContentSize()
    }
  }

  @available(iOS 16.0, *)
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: SelectableUITextView, context: Context) -> CGSize? {
    let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
    let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    return CGSize(width: width, height: size.height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onLinkTap: onLinkTap)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    let onLinkTap: ((URL) -> Void)?

    init(onLinkTap: ((URL) -> Void)?) {
      self.onLinkTap = onLinkTap
    }

    func textView(
      _ textView: UITextView,
      shouldInteractWith URL: URL,
      in characterRange: NSRange,
      interaction: UITextItemInteraction
    ) -> Bool {
      if let onLinkTap = onLinkTap {
        onLinkTap(URL)
        return false
      }
      return true
    }
  }
}

/// Custom UITextView subclass that properly calculates intrinsic content size.
@available(iOS 14.0, *)
final class SelectableUITextView: UITextView {
  override var intrinsicContentSize: CGSize {
    let width = bounds.width > 0 ? bounds.width : UIView.layoutFittingExpandedSize.width
    let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if !bounds.size.equalTo(intrinsicContentSize) {
      invalidateIntrinsicContentSize()
    }
  }
}

#endif
