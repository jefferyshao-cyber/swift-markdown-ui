import Foundation

extension Sequence where Element == BlockNode {
  /// Lifts inline HTML tags into standalone HTML blocks so they don't get rendered
  /// inside tables or other inline-only containers.
  func liftingInlineHTMLBlocks() -> [BlockNode] {
    self.rewrite { block in
      switch block {
      case .paragraph(let content):
        return content.liftedAsBlocks()
      case .table(let columnAlignments, let rows):
        var liftedBlocks: [BlockNode] = []

        let newRows = rows.map { row in
          RawTableRow(
            cells: row.cells.map { cell in
              let (content, htmlBlocks) = cell.content.removingHTMLBlocks()
              liftedBlocks.append(contentsOf: htmlBlocks)
              return RawTableCell(content: content)
            }
          )
        }

        return [.table(columnAlignments: columnAlignments, rows: newRows)] + liftedBlocks
      default:
        return [block]
      }
    }
  }
}

private extension Collection where Element == InlineNode {
  func liftedAsBlocks() -> [BlockNode] {
    var blocks: [BlockNode] = []
    var buffer: [InlineNode] = []

    func flushBuffer() {
      guard !buffer.isEmpty else { return }
      blocks.append(.paragraph(content: buffer))
      buffer.removeAll()
    }

    for inline in self {
      if case .html(let html) = inline, let tag = HTMLTag(html), !tag.isLineBreak {
        flushBuffer()
        blocks.append(.htmlBlock(tag: tag, content: html))
      } else {
        buffer.append(inline)
      }
    }

    flushBuffer()
    return blocks
  }

  func removingHTMLBlocks() -> (content: [InlineNode], htmlBlocks: [BlockNode]) {
    var content: [InlineNode] = []
    var htmlBlocks: [BlockNode] = []

    for inline in self {
      if case .html(let html) = inline, let tag = HTMLTag(html), !tag.isLineBreak {
        htmlBlocks.append(.htmlBlock(tag: tag, content: html))
      } else {
        content.append(inline)
      }
    }

    return (content, htmlBlocks)
  }
}

private extension HTMLTag {
  var isLineBreak: Bool {
    self.name.lowercased() == "br"
  }
}
