import Combine
import FacetKernel
import SwiftUI
import UniformTypeIdentifiers

/// The open pattern file. `nil` is a real state — a new document, per D3.
final class PatternDocument: ReferenceFileDocument {
  typealias Snapshot = FacetKernel.Pattern?

  @Published var pattern: FacetKernel.Pattern?

  static var readableContentTypes: [UTType] { [.json] }

  init() { pattern = nil }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    do {
      pattern = try JSONDecoder().decode(FacetKernel.Pattern.self, from: data)
    } catch {
      throw PatternReadError(underlying: error)
    }
  }

  func snapshot(contentType: UTType) throws -> FacetKernel.Pattern? { pattern }

  /// Writing goes through the kernel and nowhere else (D5, ADR-0003).
  func fileWrapper(snapshot: FacetKernel.Pattern?, configuration: WriteConfiguration) throws
    -> FileWrapper
  {
    guard let snapshot else { throw CocoaError(.featureUnsupported) }
    return FileWrapper(regularFileWithContents: try FacetKernel.encoded(snapshot))
  }
}

/// `DecodingError` and `PatternError` are neither of them `LocalizedError`, so the framework's alert
/// would show a useless string without this (D15).
struct PatternReadError: LocalizedError {
  let underlying: any Error
  var errorDescription: String? { "This file is not a valid faceting pattern." }
  var failureReason: String? { String(describing: underlying) }
}
