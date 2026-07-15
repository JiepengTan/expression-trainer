import Foundation

enum ExpressionIssueCategory: String, Codable, CaseIterable, Sendable {
    case filler
    case hesitation
    case vague
    case clarity

    var displayName: String {
        switch self {
        case .filler: "口头禅"
        case .hesitation: "犹豫词"
        case .vague: "笼统词"
        case .clarity: "表达建议"
        }
    }
}

struct UTF16TextRange: Codable, Equatable, Hashable, Sendable {
    let location: Int
    let length: Int

    var nsRange: NSRange { NSRange(location: location, length: length) }

    func intersects(_ other: UTF16TextRange) -> Bool {
        NSIntersectionRange(nsRange, other.nsRange).length > 0
    }
}

struct LexiconEntry: Codable, Equatable, Hashable, Sendable {
    let term: String
    let category: ExpressionIssueCategory
    let suggestions: [String]
}

struct ExpressionIssue: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let category: ExpressionIssueCategory
    let matchedText: String
    let range: UTF16TextRange
    let suggestions: [String]
    let segmentID: UUID?

    init(
        id: UUID = UUID(),
        category: ExpressionIssueCategory,
        matchedText: String,
        range: UTF16TextRange,
        suggestions: [String],
        segmentID: UUID? = nil
    ) {
        self.id = id
        self.category = category
        self.matchedText = matchedText
        self.range = range
        self.suggestions = suggestions
        self.segmentID = segmentID
    }
}

protocol LexiconAnalyzing: Sendable {
    func analyze(_ text: String, segmentID: UUID?) -> [ExpressionIssue]
}

extension LexiconAnalyzing {
    func analyze(_ text: String) -> [ExpressionIssue] {
        analyze(text, segmentID: nil)
    }
}

struct LexiconAnalyzer: LexiconAnalyzing {
    private let entries: [LexiconEntry]

    init(entries: [LexiconEntry]? = nil) {
        self.entries = (entries ?? LexiconCatalog.loadBundledEntries()).filter { !$0.term.isEmpty }
    }

    func analyze(_ text: String, segmentID: UUID? = nil) -> [ExpressionIssue] {
        let source = text as NSString
        var candidates: [Candidate] = []

        for entry in entries {
            var searchRange = NSRange(location: 0, length: source.length)
            while searchRange.length > 0 {
                let found = source.range(of: entry.term, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }
                candidates.append(Candidate(entry: entry, range: found))
                let nextLocation = found.location + max(found.length, 1)
                searchRange = NSRange(
                    location: nextLocation,
                    length: max(0, source.length - nextLocation)
                )
            }
        }

        candidates.sort {
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            return $0.entry.category.rawValue < $1.entry.category.rawValue
        }

        var accepted: [Candidate] = []
        for candidate in candidates {
            let range = UTF16TextRange(location: candidate.range.location, length: candidate.range.length)
            guard !accepted.contains(where: {
                range.intersects(UTF16TextRange(location: $0.range.location, length: $0.range.length))
            }) else { continue }
            accepted.append(candidate)
        }

        return accepted
            .sorted { $0.range.location < $1.range.location }
            .map {
                ExpressionIssue(
                    category: $0.entry.category,
                    matchedText: source.substring(with: $0.range),
                    range: UTF16TextRange(location: $0.range.location, length: $0.range.length),
                    suggestions: $0.entry.suggestions,
                    segmentID: segmentID
                )
            }
    }

    private struct Candidate {
        let entry: LexiconEntry
        let range: NSRange
    }
}

enum LexiconCatalog {
    static func loadBundledEntries(bundle: Bundle = .main) -> [LexiconEntry] {
        var normalized: [String: LexiconEntry] = [:]
        for entry in defaultEntries { normalized[entry.term] = entry }

        if let url = bundle.url(forResource: "emotion-lexicon", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let hesitationTokens: Set<String> = ["嗯", "啊", "呃", "额", "emmm", "唔", "啧", "哎"]
            for term in root["fillerWords"] as? [String] ?? [] {
                let category: ExpressionIssueCategory = hesitationTokens.contains(term) ? .hesitation : .filler
                normalized[term] = LexiconEntry(
                    term: term,
                    category: category,
                    suggestions: [category == .hesitation ? "用短暂停顿替代" : "删去后直接陈述"]
                )
            }
            for term in root["hedgeWords"] as? [String] ?? [] {
                normalized[term] = LexiconEntry(
                    term: term,
                    category: .hesitation,
                    suggestions: ["说明依据并给出明确判断"]
                )
            }
            if let replacements = root["vagueToPresice"] as? [String: [String]] {
                for (term, suggestions) in replacements {
                    normalized[term] = LexiconEntry(
                        term: term,
                        category: .vague,
                        suggestions: Array(suggestions.prefix(6))
                    )
                }
            }
        }

        if let url = bundle.url(forResource: "tiered-lexicon", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["vague_descriptors", "vague_verbs"] {
                guard let replacements = root[key] as? [String: [String]] else { continue }
                for (term, suggestions) in replacements where normalized[term] == nil {
                    normalized[term] = LexiconEntry(
                        term: term,
                        category: .vague,
                        suggestions: Array(suggestions.prefix(6))
                    )
                }
            }
        }

        return normalized.values.sorted {
            if $0.term.utf16.count != $1.term.utf16.count {
                return $0.term.utf16.count > $1.term.utf16.count
            }
            return $0.term < $1.term
        }
    }

    static let defaultEntries: [LexiconEntry] = [
        LexiconEntry(term: "嗯", category: .hesitation, suggestions: ["停顿后直接说重点"]),
        LexiconEntry(term: "呃", category: .hesitation, suggestions: ["用短暂停顿替代"]),
        LexiconEntry(term: "然后", category: .filler, suggestions: ["说明前后因果"]),
        LexiconEntry(term: "就是说", category: .filler, suggestions: ["删去后直接陈述"]),
        LexiconEntry(term: "我觉得", category: .filler, suggestions: ["直接给出判断"]),
        LexiconEntry(term: "可能", category: .vague, suggestions: ["说明概率或条件"]),
        LexiconEntry(term: "大概", category: .vague, suggestions: ["给出具体范围"]),
        LexiconEntry(term: "一些", category: .vague, suggestions: ["给出数量或例子"]),
        LexiconEntry(term: "这个", category: .filler, suggestions: ["说出具体对象"]),
        LexiconEntry(term: "那个", category: .filler, suggestions: ["说出具体对象"]),
        LexiconEntry(term: "差不多", category: .vague, suggestions: ["给出明确差异"]),
        LexiconEntry(term: "应该", category: .vague, suggestions: ["说明依据或承诺"])
    ]
}
