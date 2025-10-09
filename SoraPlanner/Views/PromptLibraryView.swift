//
//  PromptLibraryView.swift
//  SoraPlanner
//
//  View for managing the prompt library with persistent storage
//

import SwiftUI

struct PromptLibraryView: View {
    @StateObject private var viewModel = PromptLibraryViewModel()
    let onGeneratePrompt: (String) -> Void
    let onGenerateEmpty: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Prompt Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                // Generate with Empty Prompt Button
                Button(action: {
                    onGenerateEmpty()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate")
                    }
                }
                .help("Create new video with empty prompt")

                // Add New Prompt Button
                Button(action: {
                    viewModel.addPrompt()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .help("Add new prompt")
            }
            .padding()

            Divider()

            // Content
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error Loading Prompts")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if viewModel.prompts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Prompts Yet")
                        .font(.headline)
                    Text("Create your first prompt to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add Prompt") {
                        viewModel.addPrompt()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                // Prompt List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.prompts) { prompt in
                            PromptRow(
                                prompt: prompt,
                                viewModel: viewModel,
                                onGenerate: {
                                    print("DEBUG: PromptRow Generate button tapped - prompt.text: '\(prompt.text)'")
                                    onGeneratePrompt(prompt.text)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }
}

struct PromptRow: View {
    let prompt: Prompt
    @ObservedObject var viewModel: PromptLibraryViewModel
    let onGenerate: () -> Void

    @State private var editedPrompt: Prompt
    @State private var showDeleteConfirmation = false

    // Character limit constant
    private let maxCharacters = 2000

    init(prompt: Prompt, viewModel: PromptLibraryViewModel, onGenerate: @escaping () -> Void) {
        self.prompt = prompt
        self.viewModel = viewModel
        self.onGenerate = onGenerate
        self._editedPrompt = State(initialValue: prompt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title Field
            HStack {
                TextField("Prompt Title", text: $editedPrompt.title)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .onChange(of: editedPrompt.title) { oldValue, newValue in
                        viewModel.updatePrompt(editedPrompt)
                    }

                Spacer()

                // Delete Button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete prompt")
            }

            // Prompt Text Area
            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $editedPrompt.text)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .onChange(of: editedPrompt.text) { oldValue, newValue in
                        // Enforce character limit
                        if newValue.count > maxCharacters {
                            editedPrompt.text = String(newValue.prefix(maxCharacters))
                        }
                        viewModel.updatePrompt(editedPrompt)
                    }

                // Character count
                HStack {
                    Spacer()
                    Text("\(editedPrompt.text.count) / \(maxCharacters)")
                        .font(.caption2)
                        .foregroundColor(editedPrompt.text.count >= maxCharacters ? .red : .secondary)
                }
            }

            // Action Buttons and Metadata
            HStack {
                // Generate Button
                Button(action: {
                    onGenerate()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedPrompt.text.isEmpty)
                .help(editedPrompt.text.isEmpty ? "Add text to generate video" : "Generate video with this prompt")

                Spacer()

                // Metadata
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Created: \(formattedDate(editedPrompt.createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if editedPrompt.modifiedAt != editedPrompt.createdAt {
                        Text("Modified: \(formattedDate(editedPrompt.modifiedAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .confirmationDialog(
            "Delete Prompt?",
            isPresented: $showDeleteConfirmation,
            presenting: prompt
        ) { prompt in
            Button("Delete", role: .destructive) {
                viewModel.deletePrompt(prompt)
            }
            Button("Cancel", role: .cancel) { }
        } message: { prompt in
            Text("Are you sure you want to delete '\(prompt.title)'? This action cannot be undone.")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PromptLibraryView(
        onGeneratePrompt: { _ in },
        onGenerateEmpty: { }
    )
}
