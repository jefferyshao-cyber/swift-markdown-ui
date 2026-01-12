import SwiftUI
import MarkdownUI

struct HTMLView: View {
    private let content: String = #"""
    
        | DEX平台 | 特点 | 适用场景 |
        |---------|------|---------|
        | **Raydium** | 基于Serum订单簿的AMM，流动性最深 | 大额交易，滑点敏感用户 |
        | **Orca** | Solana原生AMM，<reference tool_id="call_46519869" category="mix_bar_line_liquidation" project="KGEN" description="KGEN liquidation risk map by price level and exchange (1d period) at 2025-11-30 10:04 UTC"/> UI最友好 | 新手首选，小额交易 |
        | **Meteora** | 高速交易引擎，动态费率 | 追求执行速度的交易者 |
    
    """#
    
    var body: some View {
        DemoView {
            Markdown(self.content)
                .htmlBlockRenderer { tag, html in
                    guard tag?.name.lowercased() == "reference" else { return nil }
                    return AnyView(
                        Text(html)
                            .padding(8)
                            .background(Color.yellow)
                            .cornerRadius(6)
                    )
                }
        }
    }
}
