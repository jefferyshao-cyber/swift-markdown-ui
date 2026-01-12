import NetworkImage
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Image Context for Multi-Image Preview

/// Context for sharing image URLs across multiple image views.
public struct ImageContext: Equatable {
  /// All image URLs in the current context.
  public var imageURLs: [URL]

  /// Creates an image context.
  public init(imageURLs: [URL] = []) {
    self.imageURLs = imageURLs
  }
}

private struct ImageContextKey: EnvironmentKey {
  static let defaultValue = ImageContext()
}

public extension EnvironmentValues {
  /// The image context for multi-image preview support.
  var imageContext: ImageContext {
    get { self[ImageContextKey.self] }
    set { self[ImageContextKey.self] = newValue }
  }
}

public extension View {
  /// Sets the image context for this view hierarchy.
  func imageContext(_ context: ImageContext) -> some View {
    environment(\.imageContext, context)
  }

  /// Sets the image URLs for multi-image preview in this view hierarchy.
  func imageContextURLs(_ urls: [URL]) -> some View {
    environment(\.imageContext, ImageContext(imageURLs: urls))
  }
}

// MARK: - Default Image Provider

/// The default image provider, which loads images from the network.
public struct DefaultImageProvider: ImageProvider {
  public init() {}

  public func makeImage(url: URL?) -> some View {
    #if canImport(UIKit)
    TappableNetworkImage(url: url)
    #else
    NetworkImage(url: url) { state in
      switch state {
      case .empty, .failure:
        Color.clear
          .frame(width: 0, height: 0)
      case .success(let image, let idealSize):
        ResizeToFit(idealSize: idealSize) {
          image.resizable()
        }
      }
    }
    #endif
  }
}

#if canImport(UIKit)
/// A network image view that supports tap-to-preview functionality.
@available(iOS 14.0, *)
struct TappableNetworkImage: View {
  @Environment(\.colorScheme) private var colorScheme

  let url: URL?

  @State private var loadedImage: UIImage?
  @State private var idealSize: CGSize = .zero
  @State private var showImageViewer = false
  @State private var loadingState: LoadingState = .loading

  private enum LoadingState {
    case loading
    case success
    case failure
  }

  /// The Dune metadata URL prefix that requires theme-based URL modification
  private static let duneMetadataPrefix = "https://metadata.asksurf.ai/dune/"

  /// Processes a URL for Dune metadata images, adding theme suffix based on colorScheme.
  private func processURL(_ url: URL?) -> URL? {
    guard let url = url else { return nil }
    let urlString = url.absoluteString

    // Check if this is a Dune metadata URL
    guard urlString.hasPrefix(Self.duneMetadataPrefix) else {
      return url
    }

    // Replace .png with _dark.png or _light.png based on colorScheme
    let themeSuffix = colorScheme == .dark ? "dark" : "light"
    let processedString = urlString.replacingOccurrences(of: ".png", with: "_\(themeSuffix).png")

    return URL(string: processedString) ?? url
  }

  /// The processed URL with theme suffix applied if needed.
  private var processedURL: URL? {
    processURL(url)
  }

  var body: some View {
    Group {
      switch loadingState {
      case .loading:
        Color.clear
          .frame(width: 0, height: 0)
      case .failure:
        Color.clear
          .frame(width: 0, height: 0)
      case .success:
        if let uiImage = loadedImage {
          ResizeToFit(idealSize: idealSize) {
            Image(uiImage: uiImage)
              .resizable()
          }
          .contentShape(Rectangle())
          .onTapGesture {
            showImageViewer = true
          }
        }
      }
    }
    .task(id: processedURL) {
      await loadImage()
    }
    .onChange(of: colorScheme) { _ in
      // Reload image when colorScheme changes
      loadingState = .loading
      loadedImage = nil
      Task {
        await loadImage()
      }
    }
    .fullScreenCover(isPresented: $showImageViewer) {
      if let image = loadedImage {
        PreviewImagesView(
          images: [image],
          startIndex: 0,
          onDismiss: { showImageViewer = false }
        )
      }
    }
  }

  private func loadImage() async {
    guard let url = processedURL else {
      loadingState = .failure
      return
    }

    loadingState = .loading

    do {
      let cgImage = try await DefaultNetworkImageLoader.shared.image(from: url)
      let uiImage = UIImage(cgImage: cgImage)

      await MainActor.run {
        self.loadedImage = uiImage
        self.idealSize = CGSize(width: cgImage.width, height: cgImage.height)
        self.loadingState = .success
      }
    } catch {
      await MainActor.run {
        self.loadingState = .failure
      }
    }
  }
}
#endif

extension ImageProvider where Self == DefaultImageProvider {
  /// The default image provider, which loads images from the network.
  ///
  /// Use the `markdownImageProvider(_:)` modifier to configure this image provider for a view hierarchy.
  public static var `default`: Self {
    .init()
  }
}
