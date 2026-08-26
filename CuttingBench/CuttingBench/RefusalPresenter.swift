import BenchGeometry
import OSLog
import Observation
import SwiftUI

/// Where a refused edit goes: an alert now and a log line forever.
///
/// One wording for both, taken from `DraftRefusal.message`, so the alert and the log can never disagree —
/// a refusal dismissed once still has to be traceable afterwards.
@Observable @MainActor final class RefusalPresenter {
  /// The sentence the alert shows, or `nil` for no alert.
  private(set) var message: String?

  /// `@ObservationIgnored` because it is not state anything observes, and `Logger` is not `Equatable`.
  @ObservationIgnored private let log = Logger(
    subsystem: "DigitalEnki.CuttingBench", category: "refusals")

  /// `nonisolated`, so a `View`'s `@State` default value can construct it: a `View` struct's own
  /// initialization is not main-actor isolated even though its `body` is.
  nonisolated init() {}

  /// Logged at `.notice` and **public**, not redacted. A refusal names a tier label and an index stop from
  /// the owner's own pattern, and a redacted log line would be useless for the one thing this exists for.
  func present(_ refusal: DraftRefusal) {
    let sentence = refusal.message
    log.notice("\(sentence, privacy: .public)")
    message = sentence
  }

  func dismiss() {
    message = nil
  }

  /// The alert's binding. **Built here rather than in the view**: its two closures read and write
  /// main-actor state, and inside a `@MainActor` type they inherit that isolation instead of needing it
  /// asserted at the call site. `SwiftUI` is imported for this one property and nothing else.
  var isPresented: Binding<Bool> {
    Binding(
      get: { self.message != nil },
      set: { shown in if !shown { self.message = nil } })
  }
}
