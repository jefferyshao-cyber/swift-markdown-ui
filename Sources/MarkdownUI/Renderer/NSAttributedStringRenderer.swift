import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

extension Sequence where Element == InlineNode {
  /// Renders inline nodes to NSAttributedString for use with UITextView.
  func renderNSAttributedString(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> NSAttributedString {
    var renderer = NSAttributedStringInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      softBreakMode: softBreakMode,
      attributes: attributes
    )
    renderer.render(self)
    return renderer.result
  }
}

private struct NSAttributedStringInlineRenderer {
  private(set) var result = NSMutableAttributedString()

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let softBreakMode: SoftBreak.Mode
  private var currentAttributes: [NSAttributedString.Key: Any]
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.softBreakMode = softBreakMode
    self.currentAttributes = Self.convertToUIKitAttributes(from: attributes)
  }

  mutating func render<S: Sequence>(_ inlines: S) where S.Element == InlineNode {
    for inline in inlines {
      render(inline)
    }
  }

  private mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      renderText(content)
    case .softBreak:
      renderSoftBreak()
    case .lineBreak:
      renderLineBreak()
    case .code(let content):
      renderCode(content)
    case .html(let content):
      renderHTML(content)
    case .emphasis(let children):
      renderEmphasis(children: children)
    case .strong(let children):
      renderStrong(children: children)
    case .strikethrough(let children):
      renderStrikethrough(children: children)
    case .link(let destination, let children):
      renderLink(destination: destination, children: children)
    case .image:
      // Images are not rendered inline - they are handled separately as block elements
      break
    }
  }

  private mutating func renderText(_ text: String) {
    var text = text

    if shouldSkipNextWhitespace {
      shouldSkipNextWhitespace = false
      text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    result.append(NSAttributedString(string: text, attributes: currentAttributes))
  }

  private mutating func renderSoftBreak() {
    switch softBreakMode {
    case .space where shouldSkipNextWhitespace:
      shouldSkipNextWhitespace = false
    case .space:
      result.append(NSAttributedString(string: " ", attributes: currentAttributes))
    case .lineBreak:
      renderLineBreak()
    }
  }

  private mutating func renderLineBreak() {
    result.append(NSAttributedString(string: "\n", attributes: currentAttributes))
    shouldSkipNextWhitespace = true
  }

  private mutating func renderCode(_ code: String) {
    var codeAttributes = currentAttributes
    Self.applyTextStyle(textStyles.code, to: &codeAttributes)
    result.append(NSAttributedString(string: code, attributes: codeAttributes))
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      renderLineBreak()
    default:
      renderText(html)
    }
  }

  private mutating func renderEmphasis(children: [InlineNode]) {
    let savedAttributes = currentAttributes
    Self.applyTextStyle(textStyles.emphasis, to: &currentAttributes)

    for child in children {
      render(child)
    }

    currentAttributes = savedAttributes
  }

  private mutating func renderStrong(children: [InlineNode]) {
    let savedAttributes = currentAttributes
    Self.applyTextStyle(textStyles.strong, to: &currentAttributes)

    for child in children {
      render(child)
    }

    currentAttributes = savedAttributes
  }

  private mutating func renderStrikethrough(children: [InlineNode]) {
    let savedAttributes = currentAttributes
    Self.applyTextStyle(textStyles.strikethrough, to: &currentAttributes)
    currentAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue

    for child in children {
      render(child)
    }

    currentAttributes = savedAttributes
  }

  private mutating func renderLink(destination: String, children: [InlineNode]) {
    let savedAttributes = currentAttributes
    Self.applyTextStyle(textStyles.link, to: &currentAttributes)

    if let url = URL(string: destination, relativeTo: baseURL) {
      currentAttributes[.link] = url
    }

    for child in children {
      render(child)
    }

    currentAttributes = savedAttributes
  }

  // MARK: - Attribute Conversion

  private static func convertToUIKitAttributes(from container: AttributeContainer) -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [:]

    // Extract font properties from the attribute container
    if let fontProperties = container.fontProperties {
      attributes[.font] = uiFont(from: fontProperties)
    } else {
      // Default font
      attributes[.font] = UIFont.systemFont(ofSize: FontProperties.defaultSize)
    }

    // Extract foreground color if available
    if let foregroundColor = container.foregroundColor {
      attributes[.foregroundColor] = UIColor(foregroundColor)
    }

    // Note: backgroundColor is intentionally NOT applied here
    // It interferes with UITextView's selection highlight

    return attributes
  }

  private static func applyTextStyle(_ style: TextStyle, to attributes: inout [NSAttributedString.Key: Any]) {
    var container = AttributeContainer()

    // Get current font properties or create default
    if let currentFont = attributes[.font] as? UIFont {
      container.fontProperties = Self.fontProperties(from: currentFont)
    } else {
      container.fontProperties = FontProperties()
    }

    // Apply the text style
    style._collectAttributes(in: &container)

    // Convert back to UIKit attributes
    if let fontProperties = container.fontProperties {
      attributes[.font] = Self.uiFont(from: fontProperties)
    }

    if let foregroundColor = container.foregroundColor {
      attributes[.foregroundColor] = UIColor(foregroundColor)
    }

    // Note: backgroundColor is intentionally NOT applied here
    // It interferes with UITextView's selection highlight
  }

  private static func uiFont(from properties: FontProperties) -> UIFont {
    let size = properties.scaledSize

    var font: UIFont

    switch properties.family {
    case .system(let design):
      let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        .withDesign(uiFontDesign(from: design)) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
      font = UIFont(descriptor: descriptor, size: size)
    case .custom(let name):
      font = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }

    // Apply weight
    let weight = uiFontWeight(from: properties.weight)
    if weight != .regular {
      let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: weight]
      let descriptor = font.fontDescriptor.addingAttributes([.traits: traits])
      font = UIFont(descriptor: descriptor, size: size)
    }

    // Apply style (italic)
    if properties.style == .italic {
      let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)
      if let descriptor = descriptor {
        font = UIFont(descriptor: descriptor, size: size)
      }
    }

    // Apply family variant (monospaced)
    if properties.familyVariant == .monospaced {
      if let descriptor = font.fontDescriptor.withDesign(.monospaced) {
        font = UIFont(descriptor: descriptor, size: size)
      }
    }

    return font
  }

  private static func uiFontDesign(from design: Font.Design) -> UIFontDescriptor.SystemDesign {
    switch design {
    case .default:
      return .default
    case .serif:
      return .serif
    case .rounded:
      return .rounded
    case .monospaced:
      return .monospaced
    @unknown default:
      return .default
    }
  }

  private static func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight:
      return .ultraLight
    case .thin:
      return .thin
    case .light:
      return .light
    case .regular:
      return .regular
    case .medium:
      return .medium
    case .semibold:
      return .semibold
    case .bold:
      return .bold
    case .heavy:
      return .heavy
    case .black:
      return .black
    default:
      return .regular
    }
  }

  private static func fontProperties(from font: UIFont) -> FontProperties {
    var properties = FontProperties()
    properties.size = font.pointSize
    properties.scale = 1

    // Try to determine weight from font descriptor
    if let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
       let weightValue = traits[.weight] as? CGFloat {
      properties.weight = Self.swiftUIFontWeight(from: UIFont.Weight(rawValue: weightValue))
    }

    // Check for italic
    if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
      properties.style = .italic
    }

    // Check for monospaced
    if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
      properties.familyVariant = .monospaced
    }

    return properties
  }

  private static func swiftUIFontWeight(from weight: UIFont.Weight) -> Font.Weight {
    switch weight {
    case .ultraLight:
      return .ultraLight
    case .thin:
      return .thin
    case .light:
      return .light
    case .regular:
      return .regular
    case .medium:
      return .medium
    case .semibold:
      return .semibold
    case .bold:
      return .bold
    case .heavy:
      return .heavy
    case .black:
      return .black
    default:
      return .regular
    }
  }
}

#endif
