import Foundation
import XCTest

@testable import MarkdownUI

final class HTMLTagTests: XCTestCase {
  func testInvalidTag() {
    XCTAssertNil(HTMLTag(""))
    XCTAssertNil(HTMLTag("foo"))
    XCTAssertNil(HTMLTag("<"))
    XCTAssertNil(HTMLTag("<>"))
  }

  func testOpeningTag() {
    // given
    let tag = HTMLTag("<sub>")

    // then
    XCTAssertEqual("sub", tag?.name)
    XCTAssertEqual(false, tag?.isSelfClosing)
    XCTAssertEqual(false, tag?.isClosing)
  }

  func testOpeningTagWithAttributes() {
    // given
    let tag = HTMLTag(
      "<img src=\"img_girl.jpg\" alt=\"Girl in a jacket\" width=\"500\" height=\"600\">"
    )

    // then
    XCTAssertEqual("img", tag?.name)
    XCTAssertEqual(false, tag?.isSelfClosing)
    XCTAssertEqual(false, tag?.isClosing)
  }

  func testClosingTag() {
    let tag = HTMLTag("</sub>")
    XCTAssertEqual(tag?.name, "sub")
    XCTAssertEqual(true, tag?.isClosing)
    XCTAssertEqual(false, tag?.isSelfClosing)
  }

  func testSelfClosingTag() {
    let tag = HTMLTag("<br />")
    XCTAssertEqual("br", tag?.name)
    XCTAssertEqual(true, tag?.isSelfClosing)
    XCTAssertEqual(false, tag?.isClosing)
  }

  func testReferenceTag() {
    XCTAssertEqual("reference", HTMLTag("<reference>")?.name)
    XCTAssertEqual("reference", HTMLTag("<reference />")?.name)
    XCTAssertEqual(true, HTMLTag("<reference />")?.isSelfClosing)
  }

  func testHTMLBlockCapturesTagMetadata() {
    let blocks = [BlockNode](markdown: "<reference />")

    guard case .htmlBlock(let tag, let content) = blocks.first else {
      return XCTFail("Expected first block to be an HTML block")
    }

    XCTAssertEqual("reference", tag?.name)
    XCTAssertEqual(true, tag?.isSelfClosing)
    XCTAssertEqual("<reference />", content.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
