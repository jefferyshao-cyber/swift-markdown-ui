import Foundation

public struct HTMLTag: Hashable {
  public let name: String
  public let isClosing: Bool
  public let isSelfClosing: Bool
}

extension HTMLTag {
  private enum Constants {
    static let tagExpression = try! NSRegularExpression(
      pattern: "<\\s*(/?)\\s*([a-zA-Z0-9]+)(?:[^>]*?)(/?)\\s*>"
    )
  }

  public init?(_ description: String) {
    guard
      let match = Constants.tagExpression.firstMatch(
        in: description,
        range: NSRange(description.startIndex..., in: description)
      ),
      let nameRange = Range(match.range(at: 2), in: description)
    else {
      return nil
    }

    self.name = String(description[nameRange])
    self.isClosing = match.range(at: 1).length > 0
    self.isSelfClosing = match.range(at: 3).length > 0
  }
}
