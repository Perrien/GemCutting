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
public indirect enum Meet: Decodable, Equatable, Sendable {
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
public struct TierSpec: Decodable, Sendable {
  public var tier: String
  public var part: Part
  public var angle: Double
  public var indices: [Int]
  /// Absent means inherit `Pattern.wheel`.
  public var wheel: Int?
  public var meet: Meet

  public init(
    tier: String,
    part: Part,
    angle: Double,
    indices: [Int],
    wheel: Int? = nil,
    meet: Meet
  ) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.indices = indices
    self.wheel = wheel
    self.meet = meet
  }
}

/// A faceting pattern as it sits on disk.
public struct Pattern: Decodable, Sendable {
  public var formatVersion: Int
  public var name: String
  public var state: PatternState
  public var wheel: Int
  public var ri: Double
  public var designer: String
  public var notes: String
  public var tiers: [TierSpec]

  public init(
    formatVersion: Int,
    name: String,
    state: PatternState,
    wheel: Int,
    ri: Double,
    designer: String,
    notes: String,
    tiers: [TierSpec]
  ) {
    self.formatVersion = formatVersion
    self.name = name
    self.state = state
    self.wheel = wheel
    self.ri = ri
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
    }
  }
}

/// A decoding failure raised before the tier label is known. `TierSpec` renames it.
enum MeetProblem: Error {
  case unknownKind(String)
  case vertexNeedsThreeFacets(Int)
  case endpointNotVertexOrTCP(endpoint: String, kind: String)
  case percentOutOfRange(Double)

  func named(tier: String) -> PatternError {
    switch self {
    case .unknownKind(let kind):
      .unknownMeetKind(tier: tier, kind: kind)
    case .vertexNeedsThreeFacets(let count):
      .vertexNeedsThreeFacets(tier: tier, count: count)
    case .endpointNotVertexOrTCP(let endpoint, let kind):
      .fractionEndpointNotVertexOrTCP(tier: tier, endpoint: endpoint, kind: kind)
    case .percentOutOfRange(let percent):
      .percentOutOfRange(tier: tier, percent: percent)
    }
  }
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
      let facets = try container.decode([FacetRef].self, forKey: .facets)
      guard facets.count == 3 else {
        throw MeetProblem.vertexNeedsThreeFacets(facets.count)
      }
      self = .vertex(facets: facets)
    case "fraction":
      let from = try container.decode(Meet.self, forKey: .from)
      let to = try container.decode(Meet.self, forKey: .to)
      let percent = try container.decode(Double.self, forKey: .percent)
      guard from.isFractionEndpoint else {
        throw MeetProblem.endpointNotVertexOrTCP(endpoint: "from", kind: from.kindName)
      }
      guard to.isFractionEndpoint else {
        throw MeetProblem.endpointNotVertexOrTCP(endpoint: "to", kind: to.kindName)
      }
      guard percent >= 0, percent <= 100 else {
        throw MeetProblem.percentOutOfRange(percent)
      }
      self = .fraction(from: from, percent: percent, to: to)
    default:
      throw MeetProblem.unknownKind(kind)
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
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let label = try container.decode(String.self, forKey: .tier)
    guard !label.isEmpty else { throw PatternError.emptyTierLabel }

    // Indices arrive as numbers so a fractional stop can be rejected by name rather than surfacing
    // as an opaque type mismatch. There are no cheaters: a published pattern sits on exact stops.
    let rawIndices = try container.decode([Double].self, forKey: .indices)
    let indices = try rawIndices.map { value -> Int in
      guard value.rounded() == value, value.magnitude < 1e9 else {
        throw PatternError.nonIntegerIndex(tier: label, value: value)
      }
      return Int(value)
    }

    let declaredWheel = try container.decodeIfPresent(Int.self, forKey: .wheel)
    if let declaredWheel, declaredWheel <= 0 {
      throw PatternError.invalidWheel(tier: label, wheel: declaredWheel)
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
      wheel: declaredWheel,
      meet: meet
    )
  }
}

extension Pattern {
  private enum CodingKeys: String, CodingKey {
    case formatVersion
    case name
    case state
    case wheel
    case ri
    case designer
    case notes
    case tiers
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let version = try container.decode(Int.self, forKey: .formatVersion)
    guard version == 1 else { throw PatternError.unsupportedFormatVersion(version) }

    let wheel = try container.decode(Int.self, forKey: .wheel)
    guard wheel > 0 else { throw PatternError.invalidWheel(tier: nil, wheel: wheel) }

    let tiers = try container.decode([TierSpec].self, forKey: .tiers)

    var seen = Set<String>()
    for tier in tiers where !seen.insert(tier.tier).inserted {
      throw PatternError.duplicateTierLabel(tier.tier)
    }

    for tier in tiers {
      let stops = tier.wheel ?? wheel
      for index in tier.indices where index < 0 || index >= stops {
        throw PatternError.indexOutOfRange(tier: tier.tier, index: index, wheel: stops)
      }
    }

    self.init(
      formatVersion: version,
      name: try container.decode(String.self, forKey: .name),
      state: try container.decode(PatternState.self, forKey: .state),
      wheel: wheel,
      ri: try container.decode(Double.self, forKey: .ri),
      designer: try container.decode(String.self, forKey: .designer),
      notes: try container.decode(String.self, forKey: .notes),
      tiers: tiers
    )
  }
}
