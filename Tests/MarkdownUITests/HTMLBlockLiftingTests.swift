import XCTest
@testable import MarkdownUI

final class HTMLBlockLiftingTests: XCTestCase {
  func testInlineHTMLIsLiftedOutOfParagraph() {
    let blocks = [BlockNode](markdown: "foo <reference /> bar").liftingInlineHTMLBlocks()

    XCTAssertEqual(blocks.count, 3)

    guard case .paragraph(let first) = blocks[0] else {
      return XCTFail("Expected first block to be a paragraph")
    }
    XCTAssertEqual(first, [.text("foo ")])

    guard case .htmlBlock(let tag, let content) = blocks[1] else {
      return XCTFail("Expected second block to be an HTML block")
    }
    XCTAssertEqual(tag?.name, "reference")
    XCTAssertEqual(content.trimmingCharacters(in: .whitespacesAndNewlines), "<reference />")

    guard case .paragraph(let last) = blocks[2] else {
      return XCTFail("Expected third block to be a paragraph")
    }
    XCTAssertEqual(last, [.text(" bar")])
  }

  func testInlineHTMLIsLiftedOutOfTableCells() {
    let markdown = """
    | a | b |
    | - | - |
    | 1 | <reference /> |
    """

    let blocks = [BlockNode](markdown: markdown).liftingInlineHTMLBlocks()

    XCTAssertEqual(blocks.count, 2)

    guard case .table(_, let rows) = blocks[0] else {
      return XCTFail("Expected first block to be a table")
    }
    XCTAssertEqual(rows.count, 2) // header + single data row

    let dataRow = rows[1]
    XCTAssertEqual(dataRow.cells[0].content, [.text("1")])
    XCTAssertTrue(dataRow.cells[1].content.isEmpty)

    guard case .htmlBlock(let tag, let content) = blocks[1] else {
      return XCTFail("Expected second block to be an HTML block")
    }
    XCTAssertEqual(tag?.name, "reference")
    XCTAssertEqual(content.trimmingCharacters(in: .whitespacesAndNewlines), "<reference />")
  }
}
