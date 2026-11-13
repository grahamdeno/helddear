import Foundation
import FoundationModels

/// Gift ideas and card words from Apple's on-device model (iOS 26 Foundation Models).
/// Runs entirely on the iPhone: nothing is sent anywhere. Available only where Apple Intelligence is on.
enum OnDeviceIdeas {
    @Generable
    struct Idea: Equatable {
        @Guide(description: "A short title for the idea, under 8 words")
        var title: String
        @Guide(description: "One sentence on why it fits this person, using the facts")
        var why: String
    }

    @Generable
    struct Ideas {
        @Guide(description: "Four different ideas", .count(4))
        var ideas: [Idea]
    }

    @Generable
    struct CardLines {
        @Guide(description: "Three different short card lines, each at most 40 characters", .count(3))
        var lines: [String]
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Why ideas can't run here, in plain words, or nil when they can.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to get ideas."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still getting ready. Try again later."
        default: return "Ideas need an iPhone with Apple Intelligence."
        }
    }

    static func gifts(for facts: PersonFacts) async throws -> [Idea] {
        let session = LanguageModelSession(instructions: IdeaPrompts.instructions)
        let response = try await session.respond(to: IdeaPrompts.gifts(facts), generating: Ideas.self)
        return response.content.ideas.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @Generable
    struct KidsIdeas {
        @Guide(description: "Three different ideas", .count(3))
        var ideas: [Idea]
    }

    static func kidsGifts(for facts: PersonFacts) async throws -> [Idea] {
        let session = LanguageModelSession(instructions: IdeaPrompts.instructions)
        let response = try await session.respond(to: IdeaPrompts.kidsGifts(facts), generating: KidsIdeas.self)
        return response.content.ideas.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static func cardWords(for facts: PersonFacts) async throws -> [String] {
        let session = LanguageModelSession(instructions: IdeaPrompts.instructions)
        let response = try await session.respond(to: IdeaPrompts.cardWords(facts), generating: CardLines.self)
        var seen = Set<String>()
        return response.content.lines.compactMap(IdeaPrompts.cleanCardLine).filter { seen.insert($0.lowercased()).inserted }
    }
}

extension PersonFacts {
    /// Facts for a person and (optionally) one Moment, from what the user saved in Held Dear.
    init(person: Person, moment: Moment?) {
        self.init(name: person.name,
                  occasion: moment?.type ?? .birthday,
                  countLine: moment?.countLine,
                  loves: person.loves,
                  sizes: person.sizes,
                  goodToKnow: person.goodToKnow,
                  mentioned: person.openWishes.map(\.text),
                  pastYears: person.sortedLedger.map(\.what))
    }
}
