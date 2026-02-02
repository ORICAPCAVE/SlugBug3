//
//  StaticTextVM.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on [112025].
//  Concept and implementation guidance collaboratively developed with assistance from ChatGPT (OpenAI).
//  This view model loads and exposes static text or Markdown resources (such as Rules.md)
//  for display within SwiftUI views like RulesView.
//

//  SlugBug3
//
//  Created by Kevin Leckenby on 10/1/25.
//
import SwiftUI
import Combine

@MainActor
final class StaticTextVM: ObservableObject {
    @Published var text: String = ""
    @Published var error: String?

    func load(resource name: String, ext: String = "md") {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            error = "Missing resource \(name).\(ext)"
            return
        }
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

