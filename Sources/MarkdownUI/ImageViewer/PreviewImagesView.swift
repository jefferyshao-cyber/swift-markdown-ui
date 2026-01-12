import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - Clear Full Screen Background

/// A helper view that clears the fullScreenCover's default background,
/// allowing the custom background opacity animation to be visible during dismiss.
public struct ClearFullScreenBackground: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - ZoomableImageView

/// Inner UIScrollView that handles zoom, pan, double-tap, and dismiss gestures for a single image.
/// Based on LazyPager's ZoomableView architecture.
final class ZoomableImageView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    // MARK: - Properties

    private let imageView: UIImageView
    private var image: UIImage?

    /// Track the base image size (aspect-fit size at zoomScale 1.0)
    private var baseImageSize: CGSize = .zero

    /// Track if we're in the middle of a zoom animation to prevent layout interference
    private var zoomGestureInProgress = false

    /// Track last bounds to detect rotation/resize
    private var lastBoundsSize: CGSize = .zero

    var onDismiss: (() -> Void)?
    var onOpacityChange: ((CGFloat) -> Void)?

    /// Whether dismiss has been triggered (to prevent multiple dismiss calls)
    private var isDismissing = false

    /// Animation duration for dismiss
    private let dismissAnimationDuration: CGFloat = 0.25

    private let doubleTapZoomScale: CGFloat = 2.5

    // MARK: - Initialization

    override init(frame: CGRect) {
        imageView = UIImageView()
        super.init(frame: frame)
        setupScrollView()
        setupImageView()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        imageView = UIImageView()
        super.init(coder: coder)
        setupScrollView()
        setupImageView()
        setupGestures()
    }

    private func setupScrollView() {
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        alwaysBounceVertical = true
        alwaysBounceHorizontal = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never

        // Critical: Set pan gesture delegate to handle gesture conflicts
        panGestureRecognizer.delegate = self
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
    }

    private func setupGestures() {
        // Double tap to zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        addGestureRecognizer(doubleTapGesture)

        // Single tap to dismiss
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        addGestureRecognizer(singleTapGesture)
    }

    // MARK: - Configuration

    func configure(with image: UIImage, configuration: ImageViewerConfiguration) {
        self.image = image
        imageView.image = image
        minimumZoomScale = configuration.minimumZoomScale
        maximumZoomScale = configuration.maximumZoomScale
        zoomScale = minimumZoomScale

        // Reset state
        zoomGestureInProgress = false
        lastBoundsSize = .zero
        baseImageSize = .zero

        setNeedsLayout()
    }

    func resetZoom(animated: Bool = false) {
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.zoomScale = self.minimumZoomScale
            } completion: { _ in
                self.updateContentInsets(centerContent: true)
            }
        } else {
            zoomScale = minimumZoomScale
            updateContentInsets(centerContent: true)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let image = image else { return }

        let boundsSize = bounds.size
        guard boundsSize.width > 0, boundsSize.height > 0 else { return }

        // Only recalculate base size when bounds change (rotation/resize) or first layout
        if lastBoundsSize != boundsSize {
            lastBoundsSize = boundsSize

            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            // Calculate aspect fit size at zoom scale 1.0
            let widthRatio = boundsSize.width / imageSize.width
            let heightRatio = boundsSize.height / imageSize.height
            let scale = min(widthRatio, heightRatio)

            baseImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

            // Set imageView frame (this is the base size, zoom will scale it)
            imageView.frame = CGRect(origin: .zero, size: baseImageSize)
            contentSize = baseImageSize

            // Reset zoom on bounds change
            if !zoomGestureInProgress {
                zoomScale = minimumZoomScale
            }

            updateContentInsets(centerContent: true)
        }
    }

    /// Update content insets to center the image (LazyPager approach)
    /// - Parameter centerContent: If true, also sets contentOffset to center the image
    private func updateContentInsets(centerContent: Bool = false) {
        let scrollViewSize = bounds.size
        let imageViewSize = imageView.frame.size

        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)

        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )

        // Center the content by scrolling into the inset area
        if centerContent {
            contentOffset = CGPoint(x: -horizontalInset, y: -verticalInset)
        }
    }

    // MARK: - Gesture Handling

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale + 0.01 {
            // Zoom out
            UIView.animate(withDuration: 0.3) {
                self.zoomScale = self.minimumZoomScale
            }
        } else {
            // Zoom in at tap location
            let location = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(doubleTapZoomScale, center: location)
            zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        // Single tap dismisses with fade animation
        guard !isDismissing else { return }
        isDismissing = true

        // Animate opacity to 0
        onOpacityChange?(0)

        // Quick fade out then dismiss
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.onDismiss?()
        }
    }

    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        // Calculate the rect in imageView coordinates
        let width = imageView.bounds.width / scale
        let height = imageView.bounds.height / scale
        let x = center.x - width / 2
        let y = center.y - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - UIGestureRecognizerDelegate

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only intercept our own pan gesture
        guard gestureRecognizer == panGestureRecognizer else {
            return true
        }

        let velocity = panGestureRecognizer.velocity(in: self)

        // Vertical swipe for dismiss - always handle
        if abs(velocity.y) > abs(velocity.x) {
            return true
        }

        // Not zoomed: let pager handle horizontal swipes
        if zoomScale <= minimumZoomScale + 0.01 {
            return false
        }

        // Zoomed: check if at edge
        let maxOffsetX = contentSize.width - bounds.width + contentInset.right
        let minOffsetX = -contentInset.left

        let isAtRightEdge = contentOffset.x >= maxOffsetX - 1.0
        let isAtLeftEdge = contentOffset.x <= minOffsetX + 1.0

        // At right edge and swiping left (to go to next image) - let pager handle
        if isAtRightEdge && velocity.x < 0 {
            return false
        }

        // At left edge and swiping right (to go to previous image) - let pager handle
        if isAtLeftEdge && velocity.x > 0 {
            return false
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous recognition - this prevents gesture conflicts
        return false
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        zoomGestureInProgress = true
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomGestureInProgress = false
        // Re-center if zoomed back to minimum scale
        let shouldCenter = scale <= minimumZoomScale + 0.01
        updateContentInsets(centerContent: shouldCenter)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Update insets to keep image centered during zoom (LazyPager approach)
        let scrollViewSize = scrollView.bounds.size
        let imageViewSize = imageView.frame.size

        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track vertical offset for dismiss gesture (only when not zoomed)
        guard zoomScale <= minimumZoomScale + 0.01 else {
            onOpacityChange?(1.0)
            return
        }

        let verticalOffset = contentOffset.y + contentInset.top
        let boundsHeight = bounds.height

        // Calculate opacity based on drag offset
        if verticalOffset < 0 || verticalOffset > 0 {
            let dragDistance = abs(verticalOffset)
            let maxDragDistance = boundsHeight * 0.5
            let opacity = max(0.3, 1.0 - (dragDistance / maxDragDistance) * 0.7)
            onOpacityChange?(opacity)
        } else {
            onOpacityChange?(1.0)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        checkForDismiss()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard zoomScale <= minimumZoomScale + 0.01 else { return }
        guard !isDismissing else { return }

        let verticalOffset = contentOffset.y + contentInset.top
        let boundsHeight = bounds.height
        let offsetPercentage = abs(verticalOffset) / boundsHeight

        // Dismiss if velocity > 1.3 and offset > 10%
        if abs(velocity.y) > 1.3 && offsetPercentage > 0.1 {
            performAnimatedDismiss(velocity: velocity.y)
        }
    }

    private func checkForDismiss() {
        guard zoomScale <= minimumZoomScale + 0.01 else { return }
        guard !isDismissing else { return }

        let verticalOffset = contentOffset.y + contentInset.top
        let boundsHeight = bounds.height
        let offsetPercentage = abs(verticalOffset) / boundsHeight

        // Dismiss if dragged more than 30% of screen
        if offsetPercentage > 0.3 {
            performAnimatedDismiss(velocity: verticalOffset < 0 ? -2.0 : 2.0)
        }
    }

    /// Performs animated dismiss with slide-out animation (for swipe gesture)
    private func performAnimatedDismiss(velocity: CGFloat) {
        guard !isDismissing else { return }
        isDismissing = true

        // Determine dismiss direction based on velocity
        // velocity < 0 means swiping down, so image should move down (positive Y)
        // velocity > 0 means swiping up, so image should move up (negative Y)
        let dismissDirection: CGFloat = velocity < 0 ? 1 : -1
        let targetY = dismissDirection * bounds.height

        // KEY: Animate background opacity to 0 at the same time as the slide animation
        // This ensures the background is fully transparent before fullScreenCover dismisses,
        // preventing any flicker from UIKit's transition animation
        onOpacityChange?(0)

        // Animate the view off screen
        let originalFrame = self.frame
        UIView.animate(withDuration: TimeInterval(dismissAnimationDuration), delay: 0, options: [.curveEaseOut]) {
            self.frame.origin.y = originalFrame.origin.y + targetY
        } completion: { _ in
            self.onDismiss?()
        }
    }
}

// MARK: - ImagePagerScrollView

/// Outer UIScrollView that handles horizontal paging between images.
final class ImagePagerScrollView: UIScrollView, UIScrollViewDelegate {

    // MARK: - Properties

    private var zoomableViews: [ZoomableImageView] = []
    private var images: [UIImage] = []
    private var configuration: ImageViewerConfiguration = .default

    var onDismiss: (() -> Void)?
    var onOpacityChange: ((CGFloat) -> Void)?
    var onPageChange: ((Int) -> Void)?

    private(set) var currentPage: Int = 0

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }

    private func setupScrollView() {
        delegate = self
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = true
        alwaysBounceHorizontal = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
    }

    // MARK: - Configuration

    func configure(with images: [UIImage], startIndex: Int, configuration: ImageViewerConfiguration) {
        self.images = images
        self.configuration = configuration
        self.currentPage = min(max(0, startIndex), max(0, images.count - 1))

        setupZoomableViews()
        setNeedsLayout()
        layoutIfNeeded()

        // Scroll to start index
        let offsetX = CGFloat(currentPage) * bounds.width
        setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
    }

    private func setupZoomableViews() {
        // Remove existing views
        zoomableViews.forEach { $0.removeFromSuperview() }
        zoomableViews.removeAll()

        // Create new zoomable views for each image
        for (index, image) in images.enumerated() {
            let zoomableView = ZoomableImageView(frame: .zero)
            zoomableView.configure(with: image, configuration: configuration)
            zoomableView.onDismiss = { [weak self] in
                self?.onDismiss?()
            }
            zoomableView.onOpacityChange = { [weak self] opacity in
                self?.onOpacityChange?(opacity)
            }
            zoomableView.tag = index
            addSubview(zoomableView)
            zoomableViews.append(zoomableView)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let pageWidth = bounds.width
        let pageHeight = bounds.height

        guard pageWidth > 0, pageHeight > 0 else { return }

        // Layout each zoomable view
        for (index, zoomableView) in zoomableViews.enumerated() {
            zoomableView.frame = CGRect(
                x: CGFloat(index) * pageWidth,
                y: 0,
                width: pageWidth,
                height: pageHeight
            )
        }

        // Update content size
        contentSize = CGSize(width: pageWidth * CGFloat(zoomableViews.count), height: pageHeight)
    }

    // MARK: - Page Navigation

    func goToPage(_ page: Int, animated: Bool) {
        guard page >= 0, page < zoomableViews.count else { return }

        let offsetX = CGFloat(page) * bounds.width
        setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
        currentPage = page
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = bounds.width
        guard pageWidth > 0 else { return }

        let page = Int(round(contentOffset.x / pageWidth))
        if page != currentPage && page >= 0 && page < zoomableViews.count {
            // Reset zoom on previous page
            if currentPage >= 0 && currentPage < zoomableViews.count {
                zoomableViews[currentPage].resetZoom(animated: false)
            }
            currentPage = page
            onPageChange?(page)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = bounds.width
        guard pageWidth > 0 else { return }

        let page = Int(round(contentOffset.x / pageWidth))
        if page >= 0 && page < zoomableViews.count {
            currentPage = page
            onPageChange?(page)
        }
    }
}

// MARK: - ImagePagerRepresentable

/// UIViewRepresentable wrapper for ImagePagerScrollView.
@available(iOS 14.0, *)
struct ImagePagerRepresentable: UIViewRepresentable {

    let images: [UIImage]
    let startIndex: Int
    let configuration: ImageViewerConfiguration
    let onDismiss: () -> Void
    let onOpacityChange: (CGFloat) -> Void
    let onPageChange: (Int) -> Void

    func makeUIView(context: Context) -> ImagePagerScrollView {
        let pagerView = ImagePagerScrollView()
        pagerView.onDismiss = onDismiss
        pagerView.onOpacityChange = onOpacityChange
        pagerView.onPageChange = onPageChange
        return pagerView
    }

    func updateUIView(_ uiView: ImagePagerScrollView, context: Context) {
        // Only configure if images changed or first time
        if context.coordinator.lastImageCount != images.count {
            uiView.configure(with: images, startIndex: startIndex, configuration: configuration)
            context.coordinator.lastImageCount = images.count
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastImageCount: Int = -1
    }
}

// MARK: - Preview Images View

/// A full-screen image preview view supporting multiple images with zoom, swipe, and drag-to-dismiss.
@available(iOS 14.0, *)
public struct PreviewImagesView: View {

    // MARK: - Properties

    @State private var currentImageIndex: Int
    @State private var backgroundOpacity: CGFloat = 1.0

    @Environment(\.imageViewerConfiguration) private var configuration

    private let images: [UIImage]
    private let onDismiss: () -> Void

    // MARK: - Initialization

    /// Creates a preview images view with pre-loaded UIImages.
    public init(
        images: [UIImage],
        startIndex: Int = 0,
        onDismiss: @escaping () -> Void
    ) {
        self.images = images
        self._currentImageIndex = State(initialValue: min(startIndex, max(0, images.count - 1)))
        self.onDismiss = onDismiss
    }

    // MARK: - Computed Properties

    private var imageCount: Int {
        images.count
    }

    /// Dismisses the view without SwiftUI animation (to avoid conflicting with our custom animation)
    private func dismissWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            onDismiss()
        }
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background
            Color(red: 0.12, green: 0.12, blue: 0.12)
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            // Content
            if !images.isEmpty {
                ImagePagerRepresentable(
                    images: images,
                    startIndex: currentImageIndex,
                    configuration: configuration,
                    onDismiss: dismissWithoutAnimation,
                    onOpacityChange: { opacity in
                        // Use same duration as dismiss animation (0.25s) for synchronization
                        withAnimation(.linear(duration: 0.25)) {
                            backgroundOpacity = opacity
                        }
                    },
                    onPageChange: { page in
                        currentImageIndex = page
                    }
                )
                .ignoresSafeArea()
            }

            // Page indicator
            if imageCount > 1 {
                VStack {
                    Spacer()
                    pageIndicator
                        .padding(.bottom, 50)
                }
            }
        }
        .background(ClearFullScreenBackground())
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onAppear {
            backgroundOpacity = 1.0
        }
    }

    // MARK: - Subviews

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<imageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
}

// MARK: - Configuration

/// Configuration for the image viewer.
public struct ImageViewerConfiguration {
    public var minimumZoomScale: CGFloat
    public var maximumZoomScale: CGFloat

    public init(
        minimumZoomScale: CGFloat = 1.0,
        maximumZoomScale: CGFloat = 5.0
    ) {
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
    }

    public static let `default` = ImageViewerConfiguration()
}

// MARK: - Environment Key

private struct ImageViewerConfigurationKey: EnvironmentKey {
    static let defaultValue = ImageViewerConfiguration.default
}

public extension EnvironmentValues {
    var imageViewerConfiguration: ImageViewerConfiguration {
        get { self[ImageViewerConfigurationKey.self] }
        set { self[ImageViewerConfigurationKey.self] = newValue }
    }
}

public extension View {
    /// Sets the image viewer configuration for this view hierarchy.
    func imageViewerConfiguration(_ configuration: ImageViewerConfiguration) -> some View {
        environment(\.imageViewerConfiguration, configuration)
    }
}

#endif
