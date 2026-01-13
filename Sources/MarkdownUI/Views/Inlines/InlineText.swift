import SwiftUI

struct InlineText: View {
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme
  @Environment(\.openURL) private var openURL

  private let inlines: [InlineNode]

  init(_ inlines: [InlineNode]) {
    self.inlines = inlines
  }

  var body: some View {
    #if canImport(UIKit)
    TextStyleAttributesReader { attributes in
      SelectableTextView(
        attributedString: self.inlines.renderNSAttributedString(
          baseURL: self.baseURL,
          textStyles: .init(
            code: self.theme.code,
            emphasis: self.theme.emphasis,
            strong: self.theme.strong,
            strikethrough: self.theme.strikethrough,
            link: self.theme.link
          ),
          softBreakMode: self.softBreakMode,
          attributes: attributes
        ),
        onLinkTap: { url in
          self.openURL(url)
        }
      )
    }
    #else
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
    #endif
  }
}
