import BenchGeometry
import Observation

/// The camera, as a reference the window owns and only the viewport region reads.
///
/// **Why a class and not window state:** while the camera was a value on the window, every drag delta
/// invalidated the whole window's body — the tier table's rows were rebuilt and its ten columns
/// re-diffed per mouse movement, which is the stutter the ticket `Bug-Dragging-The-Stone-Stutters`
/// records. As an observable reference, only the body that actually *reads* `state` is invalidated
/// when it changes, and the one body allowed to read it is `ViewportRegion`'s — so a drag re-renders
/// the Metal view and its overlays and touches nothing else. Event handlers (the orbit callback, the
/// click unprojection, the toolbar snaps) may read and write it freely: they run outside any body
/// evaluation, so they establish no dependency.
@Observable @MainActor final class BenchCameraModel {
  var state = BenchCameraState.threeQuarter

  /// `nonisolated`, so a `View`'s `@State` default value can construct it: a `View` struct's own
  /// initialization is not main-actor isolated even though its `body` is — the same reason
  /// `RefusalPresenter` declares one.
  nonisolated init() {}
}
