import Foundation

/// Whether a pattern is still being authored or is settled.
public enum PatternState: String, Codable, Sendable {
  case inProgress = "in progress"
  case finished = "finished"
}

/// One facet, named by its tier and its index on the wheel.
public struct FacetRef: Codable, Equatable, Sendable {
  public var tier: String
  public var index: Int

  public init(tier: String, index: Int) {
    self.tier = tier
    self.index = index
  }
}

/// How a tier's depth is fixed. One of exactly five forms.
public indirect enum Meet: Codable, Equatable, Sendable {
  /// The normalisation: this tier's plane offset is the unit.
  case size
  /// The free datum: this tier reaches the axis.
  case tcp
  /// The girdle band: offset from the girdle outline by the girdle thickness.
  case girdle
  /// The point where three named facets meet. Exactly three.
  case vertex(facets: [FacetRef])
  /// A point interpolated between two endpoints, each a `vertex` or a `tcp`.
  case fraction(from: Meet, percent: Double, to: Meet)

  /// The `kind` discriminator this form decodes from, for error messages.
  public var kindName: String {
    switch self {
    case .size: "size"
    case .tcp: "tcp"
    case .girdle: "girdle"
    case .vertex: "vertex"
    case .fraction: "fraction"
    }
  }

  /// Whether this form may stand at either end of a `fraction`.
  var isFractionEndpoint: Bool {
    switch self {
    case .vertex, .tcp: true
    case .size, .girdle, .fraction: false
    }
  }
}

/// A tier: one pass of the lap, at one angle, on a set of index stops, to one depth.
public struct TierSpec: Codable, Equatable, Sendable {
  public var tier: String
  public var part: Part
  public var angle: Double
  public var indices: [Int]
  /// Absent means inherit `Pattern.wheel`.
  public var wheel: Int?
  public var meet: Meet
  /// Free text for whoever cuts this tier. Never interpreted, never generated. Absent means the
  /// author wrote nothing; empty means they wrote nothing here.
  public var instructions: String?

  public init(
    tier: String,
    part: Part,
    angle: Double,
    indices: [Int],
    wheel: Int? = nil,
    meet: Meet,
    instructions: String? = nil
  ) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.indices = indices
    self.wheel = wheel
    self.meet = meet
    self.instructions = instructions
  }
}

/// A faceting pattern as it sits on disk.
public struct Pattern: Codable, Equatable, Sendable {
  public var formatVersion: Int
  public var name: String
  public var state: PatternState
  public var wheel: Int
  public var ri: Double
  /// The girdle band's thickness as a fraction of the width, as this design's diagram measures it.
  /// Absent means `defaultGirdleTargetFraction`.
  public var girdleTargetFraction: Double?
  public var designer: String
  public var notes: String
  public var tiers: [TierSpec]

  /// The 3-5% rule of thumb's midpoint, which belongs to no diagram in particular.
  public static let defaultGirdleTargetFraction = 0.04

  /// The target this pattern asks for, with the default filled in.
  public var effectiveGirdleTargetFraction: Double {
    girdleTargetFraction ?? Self.defaultGirdleTargetFraction
  }

  public init(
    formatVersion: Int,
    name: String,
    state: PatternState,
    wheel: Int,
    ri: Double,
    girdleTargetFraction: Double? = nil,
    designer: String,
    notes: String,
    tiers: [TierSpec]
  ) {
    self.formatVersion = formatVersion
    self.name = name
    self.state = state
    self.wheel = wheel
    self.ri = ri
    self.girdleTargetFraction = girdleTargetFraction
    self.designer = designer
    self.notes = notes
    self.tiers = tiers
  }

  /// The wheel a tier is cut on: its own if it declares one, otherwise the pattern's.
  public func wheel(of tier: TierSpec) -> Int {
    tier.wheel ?? wheel
  }
}

/// Everything decoding rejects. Every case that can name a tier does.
public enum PatternError: Error, Equatable, CustomStringConvertible {
  case unsupportedFormatVersion(Int)
  case duplicateTierLabel(String)
  case emptyTierLabel
  case invalidWheel(tier: String?, wheel: Int)
  case unknownMeetKind(tier: String, kind: String)
  case vertexNeedsThreeFacets(tier: String, count: Int)
  case fractionEndpointNotVertexOrTCP(tier: String, endpoint: String, kind: String)
  case percentOutOfRange(tier: String, percent: Double)
  case nonIntegerIndex(tier: String, value: Double)
  case indexOutOfRange(tier: String, index: Int, wheel: Int)
  case invalidGirdleTarget(fraction: Double)

  public var description: String {
    switch self {
    case .unsupportedFormatVersion(let version):
      "formatVersion \(version) is not supported; this kernel reads version 1"
    case .duplicateTierLabel(let label):
      "two tiers are both labelled \(label)"
    case .emptyTierLabel:
      "a tier has an empty label"
    case .invalidWheel(let tier, let wheel):
      tier.map { "tier \($0): wheel \(wheel) is not a positive stop count" }
        ?? "wheel \(wheel) is not a positive stop count"
    case .unknownMeetKind(let tier, let kind):
      "tier \(tier): \(kind) is not one of the five meet forms"
    case .vertexNeedsThreeFacets(let tier, let count):
      "tier \(tier): a vertex meet names exactly 3 facets, not \(count)"
    case .fractionEndpointNotVertexOrTCP(let tier, let endpoint, let kind):
      "tier \(tier): a fraction's \(endpoint) endpoint is a vertex or a tcp, not a \(kind)"
    case .percentOutOfRange(let tier, let percent):
      "tier \(tier): percent \(percent) is outside 0...100"
    case .nonIntegerIndex(let tier, let value):
      "tier \(tier): index \(value) is not a whole number"
    case .indexOutOfRange(let tier, let index, let wheel):
      "tier \(tier): index \(index) is outside 0..<\(wheel)"
    case .invalidGirdleTarget(let fraction):
      "girdle target \(fraction) is not a positive fraction of the width"
    }
  }
}

/// A decoding failure raised before the tier label is known. `TierSpec` renames it.
///
/// Only the unknown `kind` stays here. Every other meet rule is a statement about a `Meet` already in
/// memory, so it moved to `checkFormatRules`, where the encoder can enforce it too — but a `kind` no
/// case matches cannot become a `Meet` at all, so it has to be refused as the value is read.
enum MeetProblem: Error {
  case unknownKind(String)

  func named(tier: String) -> PatternError {
    switch self {
    case .unknownKind(let kind):
      .unknownMeetKind(tier: tier, kind: kind)
    }
  }
}

/// Every rule decoding enforces, checked against a pattern already in memory, so a file the kernel
/// writes is a file the kernel can read. `Pattern.init(from:)` runs it after decoding and `encoded`
/// runs it before encoding; `Pattern.init` itself performs no checks, which is why the encoder cannot
/// skip this.
///
/// Two rules are deliberately not here. `formatVersion` is guarded inline in `init(from:)` before the
/// tiers are read, so a version this kernel does not know is reported ahead of anything else that file
/// might also get wrong. And a non-integer index stop is a JSON-shape fault rather than a fact about a
/// `TierSpec`, whose `indices` are already `Int`.
///
/// The order below is the order today's decoder happened to check these in, kept deliberately: it is
/// what a pattern with two faults reports, and several tests name the error rather than merely
/// expecting a throw.
func checkFormatRules(_ pattern: Pattern) throws {
  guard pattern.formatVersion == 1 else {
    throw PatternError.unsupportedFormatVersion(pattern.formatVersion)
  }
  guard pattern.wheel > 0 else {
    throw PatternError.invalidWheel(tier: nil, wheel: pattern.wheel)
  }
  if let declared = pattern.girdleTargetFraction, declared <= 0 {
    throw PatternError.invalidGirdleTarget(fraction: declared)
  }

  for tier in pattern.tiers {
    guard !tier.tier.isEmpty else { throw PatternError.emptyTierLabel }
    if let declaredWheel = tier.wheel, declaredWheel <= 0 {
      throw PatternError.invalidWheel(tier: tier.tier, wheel: declaredWheel)
    }
    try checkMeetRules(tier.meet, tier: tier.tier)
  }

  var seen = Set<String>()
  for tier in pattern.tiers where !seen.insert(tier.tier).inserted {
    throw PatternError.duplicateTierLabel(tier.tier)
  }

  for tier in pattern.tiers {
    let stops = pattern.wheel(of: tier)
    for index in tier.indices where index < 0 || index >= stops {
      throw PatternError.indexOutOfRange(tier: tier.tier, index: index, wheel: stops)
    }
  }
}

/// The meet rules, for one tier. Recurses into a `fraction`'s endpoints first, so a malformed endpoint
/// is named for what is wrong with it rather than for being an endpoint.
private func checkMeetRules(_ meet: Meet, tier: String) throws {
  switch meet {
  case .size, .tcp, .girdle:
    break
  case .vertex(let facets):
    guard facets.count == 3 else {
      throw PatternError.vertexNeedsThreeFacets(tier: tier, count: facets.count)
    }
  case .fraction(let from, let percent, let to):
    try checkMeetRules(from, tier: tier)
    try checkMeetRules(to, tier: tier)
    guard from.isFractionEndpoint else {
      throw PatternError.fractionEndpointNotVertexOrTCP(
        tier: tier, endpoint: "from", kind: from.kindName)
    }
    guard to.isFractionEndpoint else {
      throw PatternError.fractionEndpointNotVertexOrTCP(
        tier: tier, endpoint: "to", kind: to.kindName)
    }
    guard percent >= 0, percent <= 100 else {
      throw PatternError.percentOutOfRange(tier: tier, percent: percent)
    }
  }
}

/// The one writer beside the one reader: runs `checkFormatRules` first, so the kernel cannot emit a
/// file it would refuse to read back.
///
/// Pretty-printed and **sorted**, because the alternative is not the authored order — it is no order at
/// all. `JSONEncoder` serialises a keyed container through an unordered dictionary and Foundation seeds
/// string hashing per process, so without `.sortedKeys` the same pattern written twice gives two
/// different files and every save is a diff. Sorted keys cost the file its authored reading order and
/// buy back a deterministic save; what order a *reader* sees is the app's to choose, and it has the
/// `Pattern` rather than the bytes.
public func encoded(_ pattern: Pattern) throws -> Data {
  try checkFormatRules(pattern)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  return try encoder.encode(pattern)
}

extension Meet {
  private enum CodingKeys: String, CodingKey {
    case kind
    case facets
    case from
    case percent
    case to
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(String.self, forKey: .kind)
    switch kind {
    case "size":
      self = .size
    case "tcp":
      self = .tcp
    case "girdle":
      self = .girdle
    case "vertex":
      self = .vertex(facets: try container.decode([FacetRef].self, forKey: .facets))
    case "fraction":
      self = .fraction(
        from: try container.decode(Meet.self, forKey: .from),
        percent: try container.decode(Double.self, forKey: .percent),
        to: try container.decode(Meet.self, forKey: .to)
      )
    default:
      throw MeetProblem.unknownKind(kind)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(kindName, forKey: .kind)
    switch self {
    case .size, .tcp, .girdle:
      break
    case .vertex(let facets):
      try container.encode(facets, forKey: .facets)
    case .fraction(let from, let percent, let to):
      try container.encode(from, forKey: .from)
      try container.encode(percent, forKey: .percent)
      try container.encode(to, forKey: .to)
    }
  }
}

extension TierSpec {
  private enum CodingKeys: String, CodingKey {
    case tier
    case part
    case angle
    case indices
    case wheel
    case meet
    case instructions
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let label = try container.decode(String.self, forKey: .tier)

    // Indices arrive as numbers so a fractional stop can be rejected by name rather than surfacing
    // as an opaque type mismatch. There are no cheaters: a published pattern sits on exact stops.
    let rawIndices = try container.decode([Double].self, forKey: .indices)
    let indices = try rawIndices.map { value -> Int in
      guard value.rounded() == value, value.magnitude < 1e9 else {
        throw PatternError.nonIntegerIndex(tier: label, value: value)
      }
      return Int(value)
    }

    let meet: Meet
    do {
      meet = try container.decode(Meet.self, forKey: .meet)
    } catch let problem as MeetProblem {
      throw problem.named(tier: label)
    }

    self.init(
      tier: label,
      part: try container.decode(Part.self, forKey: .part),
      angle: try container.decode(Double.self, forKey: .angle),
      indices: indices,
      wheel: try container.decodeIfPresent(Int.self, forKey: .wheel),
      meet: meet,
      instructions: try container.decodeIfPresent(String.self, forKey: .instructions)
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(tier, forKey: .tier)
    try container.encode(part, forKey: .part)
    try container.encode(angle, forKey: .angle)
    try container.encode(indices, forKey: .indices)
    // A tier that inherits the pattern's wheel is written without one, and prose the author did not
    // write stays unwritten: `encodeIfPresent` is what keeps absent absent through a round trip.
    try container.encodeIfPresent(wheel, forKey: .wheel)
    try container.encodeIfPresent(instructions, forKey: .instructions)
    try container.encode(meet, forKey: .meet)
  }
}

extension Pattern {
  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case name
    case state
    case wheel
    case ri
    case girdleTargetFraction
    case designer
    case notes
    case tiers
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Ahead of everything else: a version this kernel does not know says nothing else in the file can
    // be trusted to mean what it looks like.
    let version = try container.decode(Int.self, forKey: .formatVersion)
    guard version == 1 else { throw PatternError.unsupportedFormatVersion(version) }

    self.init(
      formatVersion: version,
      name: try container.decode(String.self, forKey: .name),
      state: try container.decode(PatternState.self, forKey: .state),
      wheel: try container.decode(Int.self, forKey: .wheel),
      ri: try container.decode(Double.self, forKey: .ri),
      girdleTargetFraction: try container.decodeIfPresent(
        Double.self, forKey: .girdleTargetFraction),
      designer: try container.decode(String.self, forKey: .designer),
      notes: try container.decode(String.self, forKey: .notes),
      tiers: try container.decode([TierSpec].self, forKey: .tiers)
    )

    try checkFormatRules(self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(formatVersion, forKey: .formatVersion)
    try container.encode(name, forKey: .name)
    try container.encode(state, forKey: .state)
    try container.encode(wheel, forKey: .wheel)
    try container.encode(ri, forKey: .ri)
    try container.encodeIfPresent(girdleTargetFraction, forKey: .girdleTargetFraction)
    try container.encode(designer, forKey: .designer)
    try container.encode(notes, forKey: .notes)
    try container.encode(tiers, forKey: .tiers)
  }
}
