import SwiftUI

/// A non-selectable inline text view that uses SwiftUI's native Text rendering.
/// Used for table cells where text selection is not needed.
struct NonSelectableInlineText: View {
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme

  private let inlines: [InlineNode]

  init(_ inlines: [InlineNode]) {
    self.inlines = inlines
  }

  var body: some View {
    TextStyleAttributesReader { attributes in
      self.inlines.renderText(
        baseURL: self.baseURL,
        textStyles: .init(
          code: self.theme.code,
          emphasis: self.theme.emphasis,
          strong: self.theme.strong,
          strikethrough: self.theme.strikethrough,
          link: self.theme.link
        ),
        images: [:],
        softBreakMode: self.softBreakMode,
        attributes: attributes
      )
    }
  }
}
