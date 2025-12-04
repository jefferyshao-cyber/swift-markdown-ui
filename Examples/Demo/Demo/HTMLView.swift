//
//  HTMLView.swift
//  Demo
//
//  Created by Jeffrey Shao on 2025/12/4.
//

import SwiftUI
import MarkdownUI

struct HTMLView: View {
    private let content: String = #"""
    <reference tool_id="call_46519869" category="mix_bar_line_liquidation" project="KGEN" description="KGEN liquidation risk map by price level and exchange (1d period) at 2025-11-30 10:04 UTC"/>
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
