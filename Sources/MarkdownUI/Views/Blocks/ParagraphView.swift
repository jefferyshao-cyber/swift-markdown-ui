import SwiftUI

struct ParagraphView: View {
  @Environment(\.theme.paragraph) private var paragraph
  @Environment(\.imageBaseURL) private var imageBaseURL

  private let content: [InlineNode]

  init(content: String) {
    self.init(
      content: [
        .text(content.hasSuffix("\n") ? String(content.dropLast()) : content)
      ]
    )
  }

  init(content: [InlineNode]) {
    self.content = content
  }

  var body: some View {
    self.paragraph.makeBody(
      configuration: .init(
        label: .init(self.label),
        content: .init(block: .paragraph(content: self.content))
      )
    )
  }

  /// Separates content into text-only inlines and image data
  private var separatedContent: (textInlines: [InlineNode], images: [RawImageData]) {
    var textInlines: [InlineNode] = []
    var images: [RawImageData] = []

    for inline in content {
      if let imageData = inline.imageData {
        images.append(imageData)
      } else {
        textInlines.append(inline)
      }
    }

    return (textInlines, images)
  }

  @ViewBuilder private var label: some View {
    if let imageView = ImageView(content) {
      // Single image only - render as block
      imageView
    } else if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
      let imageFlow = ImageFlow(content)
    {
      // Multiple images only - render as ImageFlow
      imageFlow
        .imageContextURLs(extractImageURLs())
    } else {
      // Mixed content - separate images from text
      let separated = separatedContent

      if separated.images.isEmpty {
        // No images - just render text
        InlineText(content)
      } else if separated.textInlines.isEmpty || separated.textInlines.allSatisfy({ $0.isWhitespaceOnly }) {
        // Only images (with optional whitespace) - render as block images
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
          ImageFlow(images: separated.images)
            .imageContextURLs(extractImageURLs())
        } else if let firstImage = separated.images.first {
          ImageView(data: firstImage)
        }
      } else {
        // Mixed content: render text first, then images as blocks
        VStack(alignment: .leading, spacing: 8) {
          // Render text without images
          InlineText(separated.textInlines)

          // Render images as block-level
          if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            ImageFlow(images: separated.images)
              .imageContextURLs(extractImageURLs())
          } else {
            ForEach(separated.images.indices, id: \.self) { index in
              ImageView(data: separated.images[index])
            }
          }
        }
      }
    }
  }

  /// Extracts all image URLs from the content for multi-image preview.
  private func extractImageURLs() -> [URL] {
    content.compactMap { inline -> URL? in
      switch inline {
      case .image(let source, _):
        return URL(string: source, relativeTo: imageBaseURL)
      case .link(_, let children) where children.count == 1:
        if case .image(let source, _) = children.first {
          return URL(string: source, relativeTo: imageBaseURL)
        }
        return nil
      default:
        return nil
      }
    }
  }
}

// MARK: - InlineNode Extensions

extension InlineNode {
  /// Returns true if this inline node is whitespace only (spaces, newlines, soft breaks)
  fileprivate var isWhitespaceOnly: Bool {
    switch self {
    case .text(let text):
      return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .softBreak, .lineBreak:
      return true
    default:
      return false
    }
  }
}
