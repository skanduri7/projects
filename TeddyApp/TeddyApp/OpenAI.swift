//
//  OpenAI.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import Foundation

enum OpenAI {

    private struct Req: Encodable {
        struct Msg: Codable {                  // ← was Encodable
            let role: String
            let content: String
        }
        let model = "gpt-4o-mini"
        let messages: [Msg]
        let temperature = 0.3
    }
    private struct Res: Decodable {
        struct Choice: Decodable { let message: Req.Msg }
        let choices: [Choice]
    }

    static func chat(user: String, context: String) async throws -> String {

        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        else { throw NSError(domain: "Teddy", code: 1,
                             userInfo: [NSLocalizedDescriptionKey:"OPENAI_API_KEY missing"]) }

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let sys = """
                  You are Teddy, a macOS screen assistant.
                  Screen context is between « ».
                  Return plain text unless you need to click, then respond \
                  as JSON: {"tool":"click","text":"Save","x":842,"y":72}
                  """
        req.httpBody = try JSONEncoder().encode(
            Req(messages: [
                .init(role:"system", content: sys),
                .init(role:"system", content: "«\(context)»"),
                .init(role:"user",   content: user)
            ])
        )

        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded   = try JSONDecoder().decode(Res.self, from: data)
        return decoded.choices.first?.message.content ?? "(no reply)"
    }
}

