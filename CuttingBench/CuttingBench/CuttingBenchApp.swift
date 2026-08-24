import SwiftUI

@main
struct CuttingBenchApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: { PatternDocument() }) { file in
      BenchWindow(document: file.document)
    }
    .commands {
      CommandGroup(after: .newItem) {
        Button("Open Pattern…") { openPatternFromPatternsFolder() }
          .keyboardShortcut("o", modifiers: [.command, .shift])
      }
    }
  }
}
