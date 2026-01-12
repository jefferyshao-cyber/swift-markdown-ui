import SwiftUI

struct HTMLBlockView: View {
  @Environment(\.htmlBlockRenderer) private var renderHTMLBlock

  let tag: HTMLTag?
  let content: String

  var body: some View {
//    if let custom = renderHTMLBlock(tag, content) {
//      custom
//    } else {
      ParagraphView(content: content)
            .textSelection(.enabled)
            .disabled(true)
    }
//  }
}
