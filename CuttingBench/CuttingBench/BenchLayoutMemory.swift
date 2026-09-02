import AppKit
import SwiftUI

/// Gives the window a layout memory. SwiftUI's own containers forget everything at quit — the window's
/// frame and the splits' dividers are all session state with no persistence API — while the AppKit
/// machinery they are built on has had per-name layout autosaving for decades. This view is the
/// bridge: invisible and zero-cost, sitting in the window only to reach that machinery and switch its
/// autosaving on.
///
/// **Every part degrades to the old behaviour.** A piece that cannot be found is left alone, so a macOS
/// release that rearranges SwiftUI's internals costs the memory, never the layout itself.
///
/// **The tier table's column widths are deliberately not covered.** SwiftUI owns them and overwrites
/// anything set from underneath; restoring them through each column's declared ideal width was tried
/// as well and did not take on this macOS release. The owner chose to drop the attempt rather than
/// chase it. The table has since been cut from ten columns to five, so the widths matter less: the
/// five that remain declare their own ideals and Instructions takes the slack.
final class LayoutMemoryView: NSView {
  /// One name per surface, shared by every bench window rather than per document: a new window opens
  /// the way the last one was arranged, which is what "remember my layout" asks for.
  static let windowName = "BenchWindow"
  static let stackedSplitName = "BenchViewportTableSplit"
  static let sideBySideSplitName = "BenchInspectorSplit"

  private var windowConfigured = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    configure()
  }

  /// Re-walks on every layout pass until each piece is found: the splits are siblings built after this
  /// view lands in the window, and the inspector's split may not exist until it is first opened. Each
  /// piece is configured exactly once — the walk itself is a few dozen views, and a piece already
  /// carrying a name is skipped.
  override func layout() {
    super.layout()
    configure()
  }

  private func configure() {
    guard let window else { return }
    if !windowConfigured {
      // Read the saved frame first, then start writing under the same name — the AppKit order.
      _ = window.setFrameUsingName(Self.windowName)
      _ = window.setFrameAutosaveName(Self.windowName)
      windowConfigured = true
    }
    guard let root = window.contentView else { return }
    for split in descendants(of: root, as: NSSplitView.self) where isUnnamed(split.autosaveName) {
      // The viewport-over-table split stacks its panes, which AppKit calls *not* vertical — the term
      // describes the dividers, not the stacking. The side-by-side split is the inspector's. Assigning
      // the name is also what restores: the split reads its saved divider the moment it is named.
      //
      // **Exactly two splits, and orientation is what tells them apart.** A third would have to be
      // identified some other way — which is one of the two reasons the table-and-detail divider is
      // not a split view at all (see `TierTableRegion`).
      split.autosaveName = split.isVertical ? Self.sideBySideSplitName : Self.stackedSplitName
    }
  }

  private func isUnnamed(_ name: String?) -> Bool { name?.isEmpty ?? true }

  private func descendants<T: NSView>(of view: NSView, as type: T.Type) -> [T] {
    var found: [T] = []
    for sub in view.subviews {
      if let match = sub as? T { found.append(match) }
      found.append(contentsOf: descendants(of: sub, as: type))
    }
    return found
  }
}

/// The SwiftUI face of the bridge, placed as a background of the window's root view.
struct LayoutMemory: NSViewRepresentable {
  func makeNSView(context: Context) -> LayoutMemoryView { LayoutMemoryView() }
  func updateNSView(_ view: LayoutMemoryView, context: Context) {}
}
