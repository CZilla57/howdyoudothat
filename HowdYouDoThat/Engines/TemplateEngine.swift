import Foundation

/// The always-available, fully-offline engine. It assembles a story from
/// randomized fragment banks tuned by tone and spiciness, filling in the
/// user's bone / location / activity. This is the guaranteed final tier of
/// the fallback chain, and the whole app runs on it in Milestone 1.
struct TemplateEngine: StoryEngine {

    func isAvailable() async -> Bool { true }

    func makeStory(for request: StoryRequest) async throws -> BrokenBoneStory {
        var rng = SystemRandomNumberGenerator()
        return Self.build(from: request, using: &rng)
    }

    // MARK: - Assembly

    static func build(from r: StoryRequest, using rng: inout some RandomNumberGenerator) -> BrokenBoneStory {
        let bone = r.bonePhrase
        let place = r.location.trimmed.isEmpty ? "somewhere I'd rather not name" : r.location.trimmed
        let activity = r.activity.trimmed.isEmpty ? "minding my own business" : r.activity.trimmed

        let banks = FragmentBanks(tone: r.tone)

        let opener = banks.openers.random(&rng)
            .replacingPlaceholders(place: place, activity: activity, bone: bone)
        let escalation = banks.escalations.random(&rng)
            .replacingPlaceholders(place: place, activity: activity, bone: bone)
        let breakMoment = banks.breaks.random(&rng)
            .replacingPlaceholders(place: place, activity: activity, bone: bone)
        let closer = banks.closers.random(&rng)
            .replacingPlaceholders(place: place, activity: activity, bone: bone)

        var sentences = [opener, escalation, breakMoment]

        if r.embellish {
            let cameo = Self.cameos.random(&rng)
                .replacingPlaceholders(place: place, activity: activity, bone: bone)
            sentences.append(cameo)
        }

        if r.spiceLevel == .wild {
            sentences.append(Self.wildKickers.random(&rng)
                .replacingPlaceholders(place: place, activity: activity, bone: bone))
        }

        if !r.audience.trimmed.isEmpty {
            sentences.append("And that, \(r.audience.trimmed), is the officially licensed version.")
        }

        sentences.append(closer)

        let story = sentences.joined(separator: " ")
        let title = banks.titles.random(&rng)
            .replacingPlaceholders(place: place, activity: activity, bone: bone)

        let oneLiners = Self.oneLiners(bone: bone, place: place, activity: activity, banks: banks, rng: &rng)

        return BrokenBoneStory(title: title, story: story, oneLiners: oneLiners, source: .template)
    }

    private static func oneLiners(
        bone: String, place: String, activity: String,
        banks: FragmentBanks, rng: inout some RandomNumberGenerator
    ) -> [String] {
        let pool = banks.oneLiners.shuffled(using: &rng)
        let count = min(3, pool.count)
        return pool.prefix(count).map {
            $0.replacingPlaceholders(place: place, activity: activity, bone: bone)
        }
    }

    // MARK: - Shared banks (tone-independent flavor)

    static let cameos = [
        "A minor celebrity was allegedly involved, but their lawyers and I have agreed I won't say who.",
        "A raccoon that clearly knew karate did not help the situation.",
        "Somewhere in the chaos, a golden retriever gave me a look of pure disappointment.",
        "An unbothered street mime witnessed everything and refused to break character.",
        "A passing goat, and I cannot stress this enough, started it."
    ]

    static let wildKickers = [
        "Three strangers applauded. One asked for my autograph. I gave it to them with my good hand.",
        "The security footage has since been described as 'unbelievable' and 'physically improbable.'",
        "I have been asked, politely, to never return to that {place}.",
        "Legend says the {activity} is still going without me."
    ]
}

// MARK: - Fragment banks per tone

private struct FragmentBanks {
    let openers: [String]
    let escalations: [String]
    let breaks: [String]
    let closers: [String]
    let titles: [String]
    let oneLiners: [String]

    init(tone: StoryTone) {
        switch tone {
        case .absurd:
            titles = ["The {bone} Incident of {place}", "How Not to {activity}", "A Completely True Account"]
            openers = [
                "So there I was at {place}, {activity}, as one does.",
                "It started, as all great {place} stories do, with me {activity}.",
                "Picture it: {place}. Me. {activity}. What could possibly go wrong?"
            ]
            escalations = [
                "Things escalated with a speed that frankly surprised the paramedics.",
                "Physics, gravity, and my own hubris formed a temporary alliance against me.",
                "One thing led to another, and 'another' turned out to be a very hard surface."
            ]
            breaks = [
                "That's the last time my {bone} and I were ever truly on speaking terms.",
                "There was a sound. Everyone agrees it was the {bone}. Nobody agrees on much else.",
                "My {bone} chose that exact moment to file its resignation."
            ]
            closers = [
                "Anyway, that's the {bone}. Thanks for asking. I regret nothing and remember less.",
                "So no, it wasn't a curb. It was destiny, and destiny broke my {bone}."
            ]
            oneLiners = [
                "Broke my {bone} at {place}. The {activity} won.",
                "{place} 1, my {bone} 0.",
                "Turns out {activity} is a contact sport.",
                "My {bone} and gravity had a disagreement. Gravity is undefeated."
            ]
        case .heroic:
            titles = ["The Legend of the {bone}", "How I Saved {place}", "A Hero's {bone}"]
            openers = [
                "They needed someone brave at {place}. I was already there, {activity}.",
                "When danger came to {place}, I did not hesitate. I was mid-{activity}.",
                "Some are born heroes. I became one at {place}, while {activity}."
            ]
            escalations = [
                "I made a split-second decision that history will surely reward.",
                "Duty called. I answered with my whole body, mostly the wrong parts.",
                "I leapt into action, and action, it turns out, does not have a soft landing."
            ]
            breaks = [
                "My {bone} paid the price so that others would not have to. A noble {bone}.",
                "The {bone} shattered, but the mission — whatever it was — did not.",
                "I broke my {bone}, but I broke it *heroically*, which counts."
            ]
            closers = [
                "You're welcome, {place}. The {bone} will heal. The legend will not.",
                "No statues yet. But the {bone} remembers, and so will you."
            ]
            oneLiners = [
                "Broke my {bone} saving {place}. Ask them.",
                "Hero stuff. {bone} was collateral.",
                "I'd do it again. I could not, physically, but I would.",
                "The {bone} is fine. The bravery is permanent."
            ]
        case .dramatic:
            titles = ["The Night the {bone} Fell", "{place}: A Tragedy", "The {bone} Monologue"]
            openers = [
                "It was a night like any other at {place}. I was {activity}. I suspected nothing.",
                "The last thing I remember is the calm — {place}, me, {activity} — before it all changed.",
                "They say tragedy comes when you least expect it. I expected nothing but {activity}."
            ]
            escalations = [
                "And then — a turn. A twist. A moment that split my life into before and after.",
                "The world tilted. Time slowed. Somewhere, dramatically, a violin gave up.",
                "In an instant, everything I knew about {activity} was rendered a lie."
            ]
            breaks = [
                "My {bone} — my faithful {bone} — could bear no more.",
                "A single, devastating crack. My {bone}. Gone, in the way {bone}s go.",
                "The {bone} broke, and with it, my perfect record of not breaking that {bone}."
            ]
            closers = [
                "And so I carry on, at {place}, a little more broken, infinitely more interesting.",
                "The {bone} will mend. But the {place} will never be the same. Nor will I."
            ]
            oneLiners = [
                "I lost my {bone} at {place}. I'd rather not relive it.",
                "One does not simply {activity} and walk away whole.",
                "The {bone}. {place}. Say no more.",
                "It was going to be a normal night of {activity}. It was not."
            ]
        case .mysterious:
            titles = ["The {place} File", "Case of the {bone}", "What Happened at {place}"]
            openers = [
                "I can tell you I was at {place}. I can tell you I was {activity}. The rest is classified.",
                "There are things about that night at {place} I'm still not allowed to say.",
                "It began at {place}. That much is certain. The {activity}? That's where it gets murky."
            ]
            escalations = [
                "Someone was there who shouldn't have been. I still don't know who.",
                "The details blur. The witnesses recant. The {activity} remains unexplained.",
                "By the time the fog cleared, the situation had changed in ways I can't fully account for."
            ]
            breaks = [
                "When I came to, my {bone} was broken and my questions had multiplied.",
                "The {bone}? Broken. The cause? Officially 'inconclusive.'",
                "All I know is the {bone} gave out. Everything else is redacted."
            ]
            closers = [
                "So don't ask me how. Ask {place}. It knows more than it lets on.",
                "The {bone} healed. The mystery did not. Sleep well."
            ]
            oneLiners = [
                "Broke my {bone} at {place}. That's all I can say.",
                "The {activity}? Classified.",
                "Some {bone}s break for reasons we're not meant to understand.",
                "I know what happened at {place}. I'll never tell."
            ]
        case .wholesome:
            titles = ["A Lovely Little {bone} Story", "The Best Worst Day at {place}", "Me, {place}, and One {bone}"]
            openers = [
                "It was honestly a great day at {place}. I was happily {activity}.",
                "Some of my favorite memories are from {place}. This one involves {activity} and, well, a {bone}.",
                "Everyone was smiling at {place}. I was {activity}. Life was good."
            ]
            escalations = [
                "Then came a tiny, well-meaning mishap that everyone still laughs about warmly.",
                "In a burst of joy, I got a *little* carried away.",
                "One enthusiastic moment too many, and gravity gently intervened."
            ]
            breaks = [
                "My {bone} took one for the team, and honestly, worth it.",
                "A small crack, a big hug afterward, and a {bone} to remember the day by.",
                "The {bone} broke, but so did everyone into helpful, loving action."
            ]
            closers = [
                "Best worst day ever. The {bone}'s healing, and the story's a keeper.",
                "Would I break my {bone} at {place} again for that memory? Probably, yeah."
            ]
            oneLiners = [
                "Broke my {bone} at {place}. Still smiled the whole way to the doctor.",
                "Happiest {bone} break of my life, no notes.",
                "{activity} + one small oops = a story I love.",
                "The {bone}'s fine and the day was perfect."
            ]
        case .conspiracy:
            titles = ["The {place} Cover-Up", "What They Don't Want You to Know About My {bone}", "The {bone} Files: Declassified"]
            openers = [
                "Officially, I was at {place}, {activity}. Officially.",
                "They'll tell you I was just {activity} at {place}. Wake up.",
                "It's all connected. {place}. The {activity}. My {bone}. Follow me here."
            ]
            escalations = [
                "That's when the pieces started falling into place — along with me.",
                "Coincidence? At {place}? I think we both know better.",
                "The 'accident' had all the hallmarks of an inside job."
            ]
            breaks = [
                "My {bone} broke, and no 'expert' has been able to explain it. Convenient.",
                "They snapped my {bone} to keep me quiet. It didn't work.",
                "The {bone} gave out. The truth, however, is still out there."
            ]
            closers = [
                "So ask yourself who really benefits from a broken {bone} at {place}.",
                "Believe the official story if you want. My {bone} and I know better."
            ]
            oneLiners = [
                "Broke my {bone} at {place}. The 'authorities' won't confirm it.",
                "The {activity} was a psy-op. My {bone} paid the price.",
                "Do your own research. Start with my {bone}.",
                "They said 'curb.' I said 'cover-up.'"
            ]
        case .fairytale:
            titles = ["Once Upon a {bone}", "The Tale of {place}", "A {bone} Most Enchanted"]
            openers = [
                "Once upon a time, in the faraway land of {place}, I was merrily {activity}.",
                "Long ago, in the kingdom of {place}, there lived a brave soul (me), {activity}.",
                "In a realm called {place}, on a morning bright, I set out {activity}."
            ]
            escalations = [
                "But alas! A wicked twist of fate had other plans.",
                "Then, as if cursed by a slighted fairy, everything went sideways.",
                "A mischievous spirit of gravity giggled, and down I went."
            ]
            breaks = [
                "And so my {bone} was broken, as foretold in no prophecy whatsoever.",
                "The {bone} snapped like a spell breaking — dramatically, and with sparkles.",
                "My poor {bone} met its enchanted end that fateful day."
            ]
            closers = [
                "And they all lived happily ever after. My {bone}, eventually.",
                "The {bone} shall mend, and the tale of {place} shall be told for ages."
            ]
            oneLiners = [
                "Once upon a time I broke my {bone} at {place}. The end.",
                "A fairytale {activity}, a cursed {bone}.",
                "Broke my {bone}. Blame the fae.",
                "Happily ever after, minus one {bone}."
            ]
        case .sportscast:
            titles = ["Game Day at {place}", "The {bone} Highlight Reel", "Replay: The {place} Incident"]
            openers = [
                "And we're LIVE at {place}, folks, where our athlete is {activity}!",
                "Welcome back to {place}! The tension is palpable as I begin {activity}.",
                "Here we go at {place} — {activity}, and the crowd can feel something coming."
            ]
            escalations = [
                "OH! Did you SEE that?! Absolutely no one saw that coming!",
                "Bold choice, ambitious, some would say ill-advised — and they'd be right!",
                "And there's the pivot — WHY would you attempt that here?!"
            ]
            breaks = [
                "And THAT is the sound of a {bone} calling it a career!",
                "The {bone} is DOWN! The {bone} is down and the trainers are sprinting!",
                "Ohhh, that's gotta hurt — the {bone} takes the full force of the play!"
            ]
            closers = [
                "We'll see him next season. The {bone}? Day to day. Back to you in the studio.",
                "An instant classic at {place}. That {bone} is on every highlight reel tonight."
            ]
            oneLiners = [
                "Broke my {bone} at {place}. What a play, what a finish!",
                "The {activity} — ten out of ten, no dismount.",
                "That {bone} left it all on the field.",
                "Injury report: {bone}, out. Legend: in."
            ]
        case .corporate:
            titles = ["Leveraging Synergies at {place}", "The {bone}: A Post-Mortem", "Q3 Learnings from {place}"]
            openers = [
                "I wanted to take a moment to share a personal learning from {place}, where I was {activity}.",
                "Humbled and honored to report that at {place}, while {activity}, I circled back on my priorities.",
                "Quick thread on resilience. It starts at {place}, with me {activity}. 🧵"
            ]
            escalations = [
                "Unfortunately, a key deliverable failed to align with my core competencies.",
                "We hit an unexpected blocker that required immediate, load-bearing pivoting.",
                "In hindsight, the risk was under-scoped and the runway was, frankly, concrete."
            ]
            breaks = [
                "Net-net, my {bone} was deprecated with immediate effect.",
                "The {bone} did not scale. We are treating it as a valuable learning.",
                "My {bone} and I have decided to part ways to pursue other opportunities."
            ]
            closers = [
                "Grateful for the journey. The {bone} taught me more than any offsite ever could.",
                "Onward and upward. The {bone} is healing, and the personal brand is thriving. 🙏"
            ]
            oneLiners = [
                "Excited to announce I broke my {bone} at {place}. #blessed",
                "The {activity} was a growth opportunity. My {bone} was the growth.",
                "Failing forward — quite literally — onto my {bone}.",
                "Broke my {bone}. Let's connect and unpack the learnings."
            ]
        case .trueCrime:
            titles = ["The {place} Tapes", "The Case of the Broken {bone}", "Dead of {place}"]
            openers = [
                "It was a quiet evening at {place}. No one could have known that {activity} would end the way it did.",
                "{place}. A place like any other. Until the night I decided to go {activity}.",
                "The victim — my {bone} — had no idea what was coming. Neither did I. I was just {activity}."
            ]
            escalations = [
                "But investigators would later identify the exact moment it all went wrong.",
                "What happened next has never been fully explained. The evidence, however, is grim.",
                "The timeline gets hazy here. What's certain is that something reached the point of no return."
            ]
            breaks = [
                "The medical examiner's report was blunt: the {bone}, broken clean through.",
                "By the time help arrived, the {bone} was gone. This was no accident. Or was it?",
                "One sound. One snap. The {bone} never stood a chance."
            ]
            closers = [
                "The {bone} would eventually heal. But the questions about {place} remain open to this day.",
                "Case closed — mostly. Sleep tight. And be careful next time you go {activity}."
            ]
            oneLiners = [
                "They found my {bone} broken at {place}. The rest is under investigation.",
                "The {activity} was the last thing my {bone} ever did.",
                "Some go {activity} and never come back whole.",
                "The {bone}: a cold case with a warm cast."
            ]
        case .western:
            titles = ["The Ballad of the {bone}", "High Noon at {place}", "There Ain't Room in {place}"]
            openers = [
                "Well now, pull up a stump. It was a dusty afternoon in {place}, and I was {activity}.",
                "They don't make {place} like they used to. Back then, I was out {activity}, mindin' my spurs.",
                "Reckon it started simple enough — {place}, a fella like me, {activity} under a hard sun."
            ]
            escalations = [
                "That's when things went sideways faster than a spooked mustang.",
                "The whole situation drew down on me before I could reach for my hat.",
                "Gravity called me out into the street, and gravity don't miss."
            ]
            breaks = [
                "My {bone} went down in a cloud of dust and a sound like a snappin' fence post.",
                "The {bone} broke clean. Out here, that's just the price of doin' business.",
                "I heard my {bone} crack, and somewhere a coyote laughed. I'm sure of it."
            ]
            closers = [
                "So that's the tale of the {bone}. Now mosey along, partner — daylight's burnin'.",
                "The {bone}'ll mend by spring. {place} won't forget me. Neither will my doctor."
            ]
            oneLiners = [
                "Broke my {bone} out in {place}. This town weren't big enough for the both of us.",
                "The {activity} was quick. My {bone} was quicker to quit.",
                "Rode into {place} whole. Limped out one {bone} short.",
                "Yeehaw and ouch, in that order."
            ]
        }
    }
}

// MARK: - Helpers

private extension Array where Element == String {
    func random(_ rng: inout some RandomNumberGenerator) -> String {
        randomElement(using: &rng) ?? (first ?? "")
    }
}

private extension String {
    func replacingPlaceholders(place: String, activity: String, bone: String) -> String {
        replacingOccurrences(of: "{place}", with: place)
            .replacingOccurrences(of: "{activity}", with: activity)
            .replacingOccurrences(of: "{bone}", with: bone)
    }
}
