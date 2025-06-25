//
//  ScreenContext.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//

import Foundation
import CoreGraphics             // for CGRect

struct ScreenContext {

    /// Return up to `limit` rows from ContextStore matching `pattern`
    /// and join them into one string.
    ///
    /// `pattern` can be `"*"` for everything or a plain substring.
    static func describe(_ pattern: String = "*", limit: Int = 50) -> String {

        // 1. most-recent rows from ContextStore
        let rows = ContextStore.shared.search(pattern).prefix(limit)

        // 2. stringify each row
        let lines = rows.map { row -> String in
            let role = row.role.isEmpty ? "" : "[\(row.role)] "

            // grab numbers from the rect
            let r   = row.rect.integral            // round to px
            let bbox = "(\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height)))"

            return "\(role)\(row.text)  \(bbox)"
        }

        return lines.joined(separator: "\n")
    }

}

