import MarkdownUI
import SwiftUI

struct ImagesView: View {
  private let content = """
    You can display an image by adding `!` and wrapping the alt text in `[ ]`.
    Then wrap the link for the image in parentheses `()`.

    ```
    ![This is an image](https://picsum.photos/id/91/400/300)
    ```

    ![This is an image](https://picsum.photos/id/91/400/300)
    
    
    ### 1. Transaction Volume and Network Activity
    - **Daily transactions**: 1.83 million (2026-01-12)
    - **Active addresses**: 645,596 (24h)
    - **New addresses**: 64,793 (24h) - **110% increase since Fusaka upgrade**

    The sustained high transaction volume indicates robust network utilization, while the address growth suggests expanding user adoption post-upgrades.

    ### 2. Revenue and Fee Dynamics
    
    ![Ethereum Daily Revenue Peaks](https://metadata.asksurf.ai/dune/8687316/5293093.png)
    *Revenue spikes exceeding $40M demonstrate network value capture during high-activity periods*

    **Revenue composition shift** is particularly telling:
    - **MEV Tips + Priority Fees**: >80% share during high-volatility periods
    - **Base Fees**: <20% share (down from nearly 100% pre-2025)
    - **Blob Submissions**: Negligible but growing contribution

    ― Photo by Jennifer Trovato
    """

  private let inlineImageContent = """
    You can also insert images in a line of text, such as
    ![](https://picsum.photos/id/237/50/25) or
    ![](https://picsum.photos/id/433/50/25).

    ```
    You can also insert images in a line of text, such as
    ![](https://picsum.photos/id/237/50/25) or
    ![](https://picsum.photos/id/433/50/25).
    ```

    Note that MarkdownUI **cannot** apply any styling to
    inline images.

    ― Photos by André Spieker and Thomas Lefebvre
    """

  var body: some View {
    DemoView {
      Markdown(self.content)

      Section("Inline images") {
        Markdown(self.inlineImageContent)
      }

      Section("Customization Example") {
        Markdown(self.content)
      }
      .markdownBlockStyle(\.image) { configuration in
        configuration.label
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .shadow(radius: 8, y: 8)
          .markdownMargin(top: .em(1.6), bottom: .em(1.6))
      }
    }
  }
}

struct ImagesView_Previews: PreviewProvider {
  static var previews: some View {
    ImagesView()
  }
}
