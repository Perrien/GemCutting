import BenchGeometry
import Combine
import FacetKernel
import SwiftUI
import UniformTypeIdentifiers

/// The open pattern file, as a draft. A new document is an empty draft, which displays as the bare prism.
final class PatternDocument: ReferenceFileDocument {
  typealias Snapshot = PatternDraft

  @Published var draft: PatternDraft = .empty

  /// What everything downstream solves and displays. Computed and never stored: one draft, one derived
  /// pattern, so no readout can disagree with the draft.
  var pattern: FacetKernel.Pattern? { draft.displayPattern }

  static var readableContentTypes: [UTType] { [.json] }

  init() { draft = .empty }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    do {
      draft = PatternDraft(try JSONDecoder().decode(FacetKernel.Pattern.self, from: data))
    } catch {
      throw PatternReadError(underlying: error)
    }
  }

  func snapshot(contentType: UTType) throws -> PatternDraft { draft }

  /// Writing goes through the kernel and nowhere else (ADR-0003). A draft with a tier whose meet is not
  /// chosen yet has no file form at all, so the save refuses and names what is missing rather than
  /// quietly dropping the tier.
  func fileWrapper(snapshot: PatternDraft, configuration: WriteConfiguration) throws
    -> FileWrapper
  {
    switch snapshot.completePattern() {
    case .success(let pattern):
      return FileWrapper(regularFileWithContents: try FacetKernel.encoded(pattern))
    case .failure(let refusal):
      throw DraftSaveError(refusal: refusal)
    }
  }

  /// One edit, one undo entry. Returns the refusal for the caller to present, or `nil` when the edit
  /// landed.
  ///
  /// The undo closure applies the *previous whole draft* through this same method, which is what makes
  /// redo work without a second code path: registering it registers its own undo in turn. A draft is a
  /// few dozen value-typed tiers, so a whole-value snapshot cannot get its inverse wrong the way a
  /// per-field inverse operation can.
  @discardableResult
  func apply(_ change: DraftChange, undoManager: UndoManager?, actionName: String)
    -> DraftRefusal?
  {
    let previous = draft
    switch change(previous) {
    case .failure(let refusal):
      return refusal
    case .success(let edited):
      // An edit equal to the current draft registers no undo: choosing the meet a tier already has is not
      // a step the owner should have to walk back through.
      guard edited != previous else { return nil }
      draft = edited
      undoManager?.registerUndo(withTarget: self) { document in
        document.apply(
          { _ in .success(previous) }, undoManager: undoManager, actionName: actionName)
      }
      undoManager?.setActionName(actionName)
      return nil
    }
  }
}

/// `DecodingError` and `PatternError` are neither of them `LocalizedError`, so the framework's alert
/// would show a useless string without this.
struct PatternReadError: LocalizedError {
  let underlying: any Error
  var errorDescription: String? { "This file is not a valid faceting pattern." }
  var failureReason: String? { String(describing: underlying) }
}

/// A save the draft cannot answer. `DraftRefusal` is not `LocalizedError` either, and its `message` is the
/// same sentence the edit alert shows — one wording, so the save sheet and the alert cannot disagree.
struct DraftSaveError: LocalizedError {
  let refusal: DraftRefusal
  var errorDescription: String? { "This pattern cannot be saved yet." }
  var failureReason: String? { refusal.message }
}
