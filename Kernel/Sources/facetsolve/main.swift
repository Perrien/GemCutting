import FacetKernel
import Foundation

// facetsolve — loads a pattern, solves it, validates it, and prints what it found.
//
//   facetsolve <pattern.json> [--json] [--girdle <fraction>]
//
// A library has nothing to look at, so this is how a headless kernel gets verified. It is a permanent
// diagnostic and not the app.
//
// Exit code 0 when the pattern comes back with no findings, 1 when a finished pattern does not.
// Notices never affect it: a tier cut away entirely is legitimate, and only a reader can tell that
// from a mis-authored depth. A pattern still in progress prints its findings as informational and exits
// 0, since it is not claiming to be valid yet. A pattern the solver refuses exits 1 whatever its state —
// there is nothing to report but the fault. Usage, file and decoding failures exit 2 and print on
// stderr, so `--json`'s stdout stays a single JSON object.

// MARK: - Arguments

/// What the command line asked for.
struct Options {
  let path: String
  let json: Bool
  /// The girdle band's thickness as a fraction of the width, when the flag overrides the pattern's own
  /// declared target. `nil` means the flag was not given and the file's value stands.
  let girdle: Double?

  init(_ arguments: [String]) throws {
    var path: String?
    var json = false
    var girdle: Double?

    var rest = arguments[...]
    while let argument = rest.popFirst() {
      switch argument {
      case "--json":
        json = true
      case "--girdle":
        guard let value = rest.popFirst(), let fraction = Double(value) else {
          throw UsageError.girdleNeedsAFraction
        }
        girdle = fraction
      default:
        guard !argument.hasPrefix("-") else { throw UsageError.unknownFlag(argument) }
        guard path == nil else { throw UsageError.onePatternAtATime }
        path = argument
      }
    }

    guard let path else { throw UsageError.noPattern }
    self.path = path
    self.json = json
    self.girdle = girdle
  }
}

enum UsageError: Error, CustomStringConvertible {
  case noPattern
  case onePatternAtATime
  case unknownFlag(String)
  case girdleNeedsAFraction

  var description: String {
    switch self {
    case .noPattern: "no pattern given"
    case .onePatternAtATime: "one pattern at a time"
    case .unknownFlag(let flag): "\(flag) is not a flag this reads"
    case .girdleNeedsAFraction: "--girdle takes a fraction of the width, as in --girdle 0.0337"
    }
  }
}

let usage = "usage: facetsolve <pattern.json> [--json] [--girdle <fraction>]"

// MARK: - Printing

func out(_ line: String) {
  print(line)
}

func die(_ code: Int32, _ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(code)
}

/// Findings print in the shape the library names them, so the output and the source say the same thing.
func printed(_ finding: Finding) -> String {
  "\(finding)"
}

/// Notices print as prose. They are addressed to whoever is reading, not to a differ.
func printed(_ notice: Notice) -> String {
  switch notice {
  case .tierContributesNoFacets(let tier):
    "tier \(tier) contributes no facets"
  case .duplicatePlanes(let tier, let indices):
    "tier \(tier) cuts index \(indices.map(String.init).joined(separator: ", ")) twice"
  }
}

/// The solver refuses a pattern for faults validation reports as findings, and the two name them
/// identically. The shared five print in the `Finding` spelling so the output has one vocabulary; the
/// rest are the solver's own.
func printed(_ error: SolverError) -> String {
  switch error {
  case .forwardReference(let tier, let named):
    printed(Finding.forwardReference(tier: tier, named: named))
  case .namesOwnFacet(let tier):
    printed(Finding.namesOwnFacet(tier: tier))
  case .unknownFacet(let tier, let named):
    printed(Finding.unknownFacet(tier: tier, named: named))
  case .singularTriple(let tier):
    printed(Finding.singularTriple(tier: tier))
  case .secondTCPOnSide(let tier, let part):
    printed(Finding.secondTCPOnSide(tier: tier, part: part))
  case .noAxialPointOnSide, .girdleOutlineUndetermined, .vertexNeedsThreeFacets,
    .fractionEndpointNotVertexOrTCP, .tierHasNoIndices:
    error.description
  }
}

/// One heading per channel, and the count in front of it. A single item sits on the heading's own line,
/// which is the common case and the one worth reading at a glance.
func printChannel(_ name: String, _ items: [String]) {
  switch items.count {
  case 0:
    out("no \(name)s")
  case 1:
    out("1 \(name): \(items[0])")
  default:
    out("\(items.count) \(name)s:")
    for item in items { out("  \(item)") }
  }
}

func row(_ label: String, _ value: String) -> String {
  "  " + label.padding(toLength: 18, withPad: " ", startingAt: 0) + value
}

func fixed(_ value: Double, _ places: Int) -> String {
  String(format: "%.\(places)f", value)
}

// MARK: - JSON

/// The machine-readable form: metrics, findings and notices, and nothing else.
///
/// Doubles are written to nine places so a golden fixture compares on the geometry rather than on the
/// last bit of a `Double`. Nine is well past every tolerance this kernel is checked to.
///
/// **The `observations` key keeps its name although the library's type is now `Notice`.** The three
/// authored patterns' golden fixtures are saved copies of this object and are external ground truth that
/// is never edited, so the wire name is frozen and the Swift name is mapped onto it here.
struct JSONReport: Encodable {
  let metrics: JSONMetrics?
  let findings: [String]
  let notices: [String]

  private enum CodingKeys: String, CodingKey {
    case metrics
    case findings
    case notices = "observations"
  }

  /// All three keys are always written, `metrics` as `null` when the solver refused the pattern. A reader
  /// that has to check whether a key is there is a reader that will forget to.
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(metrics, forKey: .metrics)
    try container.encode(findings, forKey: .findings)
    try container.encode(notices, forKey: .notices)
  }
}

struct JSONMetrics: Encodable {
  let facetCount: Int
  let facetsPerTier: [String: Int]
  let rotationalOrder: Int
  let mirrorAxes: [Int]
  let widthNormalised: Double
  let lengthNormalised: Double
  let lengthOverWidth: Double
  let totalDepthFractionOfWidth: Double
  let pavilionDepthFractionOfWidth: Double
  let crownHeightFractionOfWidth: Double
  let tableFractionOfWidth: Double
  let girdleThicknessNormalised: Double
  let girdleFractionOfWidth: Double
  let culetIsPoint: Bool

  init(_ measured: Metrics) {
    facetCount = measured.facetCount
    facetsPerTier = measured.facetsPerTier
    rotationalOrder = measured.rotationalOrder
    mirrorAxes = measured.mirrorAxes
    widthNormalised = place(measured.widthNormalised)
    lengthNormalised = place(measured.lengthNormalised)
    lengthOverWidth = place(measured.lengthOverWidth)
    totalDepthFractionOfWidth = place(measured.totalDepthFractionOfWidth)
    pavilionDepthFractionOfWidth = place(measured.pavilionDepthFractionOfWidth)
    crownHeightFractionOfWidth = place(measured.crownHeightFractionOfWidth)
    tableFractionOfWidth = place(measured.tableFractionOfWidth)
    girdleThicknessNormalised = place(measured.girdleThicknessNormalised)
    girdleFractionOfWidth = place(measured.girdleFractionOfWidth)
    culetIsPoint = measured.culetIsPoint
  }
}

func place(_ value: Double) -> Double {
  (value * 1e9).rounded() / 1e9
}

func emit(_ report: JSONReport) {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  guard let data = try? encoder.encode(report),
    let text = String(data: data, encoding: .utf8)
  else {
    die(2, "could not write the report as JSON")
  }
  out(text)
}

// MARK: - Run

let options: Options
do {
  options = try Options(Array(CommandLine.arguments.dropFirst()))
} catch {
  die(2, "\(error)\n\(usage)")
}

let pattern: Pattern
do {
  let data = try Data(contentsOf: URL(fileURLWithPath: options.path))
  pattern = try JSONDecoder().decode(Pattern.self, from: data)
} catch let error as PatternError {
  die(2, "\(options.path): \(error)")
} catch {
  die(2, "\(options.path): \(error.localizedDescription)")
}

let solution: Solution
do {
  solution = try solve(pattern, girdleTargetFraction: options.girdle)
} catch let error as SolverError {
  // The solve refuses to guess, so there is no solid and no metrics — only the fault.
  if options.json {
    emit(JSONReport(metrics: nil, findings: [printed(error)], notices: []))
  } else {
    out(pattern.name)
    printChannel("finding", [printed(error)])
  }
  exit(1)
} catch {
  die(2, "\(options.path): \(error)")
}

let report = validate(pattern, solution, declaredFacetCount: nil)
let measured = metrics(solution)
/// What the solve actually used: the flag when it was given, otherwise the pattern's own target.
let resolvedGirdleTarget = options.girdle ?? pattern.effectiveGirdleTargetFraction

let findings = report.findings.map(printed)
let notices = report.notices.map(printed)

if options.json {
  emit(
    JSONReport(
      metrics: JSONMetrics(measured),
      findings: findings,
      notices: notices
    ))
} else {
  out(pattern.name)
  out(
    "  \(pattern.state.rawValue), wheel \(pattern.wheel), RI \(fixed(pattern.ri, 3)), "
      + "girdle target \(fixed(resolvedGirdleTarget * 100, 3))% of width")
  out("")

  out("tiers")
  for (spec, solved) in zip(pattern.tiers, solution.tiers) {
    let label = solved.tier.padding(toLength: 4, withPad: " ", startingAt: 0)
    let part = spec.part.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)
    let form = spec.meet.kindName.padding(toLength: 9, withPad: " ", startingAt: 0)
    let angle = fixed(spec.angle, 2).leftPadded(to: 6)
    out("  \(label) \(part) \(angle) \(form) d = \(fixed(solved.d, 6))")
  }
  out("")

  out("metrics")
  out(row("facets", "\(measured.facetCount)"))
  out(
    row(
      "per tier",
      measured.facetsPerTier.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        .joined(separator: "  ")))
  out(
    row(
      "symmetry",
      "\(measured.rotationalOrder)-fold"
        + (measured.mirrorAxes.isEmpty
          ? ", no mirror axis"
          : ", mirrors at \(measured.mirrorAxes.map(String.init).joined(separator: " "))")))
  out(row("width", fixed(measured.widthNormalised, 6)))
  out(row("length", fixed(measured.lengthNormalised, 6)))
  out(row("L/W", fixed(measured.lengthOverWidth, 5)))
  out(
    row(
      "girdle",
      "\(fixed(measured.girdleThicknessNormalised, 6)) "
        + "(\(fixed(measured.girdleFractionOfWidth * 100, 3))% of width)"))
  out(
    row(
      "proportions",
      "P/W \(fixed(measured.pavilionDepthFractionOfWidth, 3))  "
        + "C/W \(fixed(measured.crownHeightFractionOfWidth, 3))  "
        + "H/W \(fixed(measured.totalDepthFractionOfWidth, 3))  "
        + "T/W \(fixed(measured.tableFractionOfWidth, 3))"))
  out(row("culet", measured.culetIsPoint ? "point" : "facet"))
  out("")

  printChannel("finding", findings)
  // The printed word stays "observation" for the same reason the JSON key does: the golden fixtures.
  printChannel("observation", notices)
}

// A finished pattern is claiming to be valid, so its findings are fatal. An unfinished one is not, and a
// notice never is.
exit(findings.isEmpty || pattern.state == .inProgress ? 0 : 1)

extension String {
  fileprivate func leftPadded(to width: Int) -> String {
    count >= width ? self : String(repeating: " ", count: width - count) + self
  }
}
