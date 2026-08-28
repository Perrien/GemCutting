import SwiftUI

/// The focused window's quarter-turn action. **A closure rather than the document**: the turn is an edit,
/// and edits go through the window's own funnel, which owns the undo manager and the refusal presenter.
private struct TurnAQuarterKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
  var turnAQuarter: (() -> Void)? {
    get { self[TurnAQuarterKey.self] }
    set { self[TurnAQuarterKey.self] = newValue }
  }
}

/// The Pattern menu: operations over the whole pattern rather than one tier. One item so far (D19).
///
/// **The item is not disabled for a pattern that cannot be turned** (D17): a greyed-out item explains
/// nothing, while the refusal names the tier and the gear that stopped it.
struct PatternCommands: Commands {
  @FocusedValue(\.turnAQuarter) private var turnAQuarter

  var body: some Commands {
    CommandMenu("Pattern") {
      Button("Turn a Quarter Turn") { turnAQuarter?() }
        .disabled(turnAQuarter == nil)
    }
  }
}
