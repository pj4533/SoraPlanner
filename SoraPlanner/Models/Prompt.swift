//
//  Prompt.swift
//  SoraPlanner
//
//  Created by Claude Code
//

import Foundation

/// A reusable video generation prompt with metadata
struct Prompt: Identifiable, Codable {
    let id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Prompt",
        text: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
