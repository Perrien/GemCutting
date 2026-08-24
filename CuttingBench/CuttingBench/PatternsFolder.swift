import AppKit
import UniformTypeIdentifiers

/// `Design/Patterns/` in the checkout this binary was built from, or `nil` in a release build.
///
/// Derived from `#filePath` — this file sits at `<repo>/CuttingBench/CuttingBench/`, so the repository
/// root is three levels up. Never existence-checked: the App Sandbox cannot stat a path outside the
/// container, so the check would say `false` for a directory that is really there (D8).
var patternsFolder: URL? {
  #if DEBUG
    URL(filePath: #filePath)
      .deletingLastPathComponent()  // CuttingBench/CuttingBench
      .deletingLastPathComponent()  // CuttingBench
      .deletingLastPathComponent()  // repository root
      .appending(path: "Design/Patterns", directoryHint: .isDirectory)
  #else
    nil
  #endif
}

/// Runs the app's own Open dialog, started in `Design/Patterns/`, and opens what the owner picks.
@MainActor
func openPatternFromPatternsFolder() {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.json]
  panel.allowsMultipleSelection = false
  panel.canChooseDirectories = false
  panel.message = "Choose a faceting pattern."
  if let patternsFolder { panel.directoryURL = patternsFolder }
  guard panel.runModal() == .OK, let url = panel.url else { return }
  NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
}
