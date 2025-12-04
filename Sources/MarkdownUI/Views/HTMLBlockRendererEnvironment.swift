import SwiftUI

/// A closure used to render HTML block nodes. Return `nil` to fall back to the default rendering.
public typealias HTMLBlockRenderer = (_ tag: HTMLTag?, _ content: String) -> AnyView?

private struct HTMLBlockRendererKey: EnvironmentKey {
  static let defaultValue: HTMLBlockRenderer = { _, _ in nil }
}

public extension EnvironmentValues {
  var htmlBlockRenderer: HTMLBlockRenderer {
    get { self[HTMLBlockRendererKey.self] }
    set { self[HTMLBlockRendererKey.self] = newValue }
  }
}

public extension View {
  /// Inject a custom renderer for HTML block nodes.
  /// - Parameter renderer: Return a custom view for the given tag/content, or `nil` to defer to the default rendering.
  func htmlBlockRenderer(_ renderer: @escaping HTMLBlockRenderer) -> some View {
    environment(\.htmlBlockRenderer, renderer)
  }
}
