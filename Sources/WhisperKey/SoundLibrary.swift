import Foundation

enum ResenhaSoundCategory: String, CaseIterable, Identifiable {
    case bodily
    case reactions
    case instruments
    case playful
    case nature
    case abstract
    case angelic

    var id: Self { self }
    var title: String {
        switch self {
        case .bodily: "Zoeira corporal"
        case .reactions: "Vozes e reações"
        case .instruments: "Objetos e instrumentos"
        case .playful: "Games e desenhos"
        case .nature: "Animais e natureza"
        case .abstract: "Abstratos"
        case .angelic: "Angelicais"
        }
    }
    var symbol: String {
        switch self {
        case .bodily: "face.smiling"
        case .reactions: "quote.bubble"
        case .instruments: "bell"
        case .playful: "gamecontroller"
        case .nature: "leaf"
        case .abstract: "waveform"
        case .angelic: "sparkles"
        }
    }
}

enum ResenhaSoundKind: Int, Hashable {
    case burp, flatulence, breath, vocal, bell, percussion, retro, animal, abstract, angelic
}

struct ResenhaSound: Identifiable, Hashable {
    let id: Int
    let name: String
    let category: ResenhaSoundCategory
    let kind: ResenhaSoundKind
    let frequency: Double
    let endFrequency: Double
    let duration: Double
    let character: Double
    let seed: UInt64

    var numberedName: String { String(format: "%02d — %@", id, name) }
}

enum ResenhaSoundCatalog {
    static let defaultSoundID = 60
    static let all: [ResenhaSound] = [
        sound(1, "Arroto curto", .bodily, .burp, 118, 82, 0.26, 0.40),
        sound(2, "Arroto tímido", .bodily, .burp, 155, 112, 0.21, 0.18),
        sound(3, "Pum seco", .bodily, .flatulence, 82, 54, 0.19, 0.78),
        sound(4, "Pum de desenho", .bodily, .flatulence, 126, 46, 0.34, 0.96),
        sound(5, "Tosse discreta", .bodily, .breath, 170, 105, 0.25, 0.30),
        sound(6, "Espirro", .bodily, .breath, 290, 95, 0.31, 0.92),
        sound(7, "Soluço", .bodily, .vocal, 210, 310, 0.20, 0.74),
        sound(8, "Fungada", .bodily, .breath, 260, 180, 0.22, 0.12),
        sound(9, "Bocejo", .bodily, .vocal, 185, 120, 0.42, 0.15),
        sound(10, "Limpando a garganta", .bodily, .breath, 145, 92, 0.35, 0.62),

        sound(11, "Opa!", .reactions, .vocal, 235, 360, 0.28, 0.42),
        sound(12, "Vai!", .reactions, .vocal, 280, 470, 0.22, 0.72),
        sound(13, "Fala!", .reactions, .vocal, 205, 330, 0.30, 0.55),
        sound(14, "Valendo!", .reactions, .vocal, 220, 440, 0.38, 0.88),
        sound(15, "Manda!", .reactions, .vocal, 245, 390, 0.27, 0.64),
        sound(16, "Gravando!", .reactions, .vocal, 190, 350, 0.40, 0.34),
        sound(17, "Bora!", .reactions, .vocal, 260, 415, 0.26, 0.81),
        sound(18, "Risadinha", .reactions, .vocal, 330, 510, 0.36, 0.95),
        sound(19, "Aham", .reactions, .vocal, 175, 235, 0.32, 0.22),
        sound(20, "Assobio curto", .reactions, .animal, 720, 1_180, 0.30, 0.08),

        sound(21, "Sino de balcão", .instruments, .bell, 780, 780, 0.34, 0.64),
        sound(22, "Sineta escolar", .instruments, .bell, 1_080, 1_080, 0.39, 0.88),
        sound(23, "Triângulo", .instruments, .bell, 1_430, 1_430, 0.33, 0.28),
        sound(24, "Agogô", .instruments, .bell, 610, 930, 0.36, 0.48),
        sound(25, "Cuíca", .instruments, .animal, 260, 690, 0.32, 0.93),
        sound(26, "Berimbau curto", .instruments, .percussion, 185, 255, 0.31, 0.24),
        sound(27, "Pandeiro", .instruments, .percussion, 230, 165, 0.28, 0.78),
        sound(28, "Castanhola", .instruments, .percussion, 710, 520, 0.22, 0.38),
        sound(29, "Taça brindando", .instruments, .bell, 1_260, 1_590, 0.41, 0.16),
        sound(30, "Campainha de bicicleta", .instruments, .bell, 940, 1_180, 0.38, 0.72),

        sound(31, "Moeda coletada", .playful, .retro, 620, 1_240, 0.24, 0.82),
        sound(32, "Power-up", .playful, .retro, 330, 990, 0.39, 0.58),
        sound(33, "Checkpoint", .playful, .retro, 440, 660, 0.30, 0.18),
        sound(34, "Laser retrô", .playful, .retro, 1_250, 180, 0.31, 0.92),
        sound(35, "Bolha estourando", .playful, .percussion, 520, 110, 0.20, 0.68),
        sound(36, "Mola boing", .playful, .animal, 180, 510, 0.37, 0.85),
        sound(37, "Trombone triste", .playful, .vocal, 260, 125, 0.43, 0.10),
        sound(38, "Corneta de festa", .playful, .vocal, 310, 540, 0.34, 0.90),
        sound(39, "Tambor de suspense", .playful, .percussion, 105, 72, 0.42, 0.56),
        sound(40, "Vitória de 8 bits", .playful, .retro, 392, 1_176, 0.46, 0.36),

        sound(41, "Latido curto", .nature, .animal, 185, 92, 0.28, 0.84),
        sound(42, "Miado", .nature, .animal, 310, 540, 0.38, 0.44),
        sound(43, "Pato quá", .nature, .animal, 220, 145, 0.27, 0.72),
        sound(44, "Galinha", .nature, .animal, 410, 250, 0.33, 0.61),
        sound(45, "Galo", .nature, .animal, 290, 610, 0.43, 0.94),
        sound(46, "Sapo", .nature, .animal, 118, 82, 0.32, 0.16),
        sound(47, "Grilo", .nature, .animal, 2_300, 2_650, 0.29, 0.53),
        sound(48, "Coruja", .nature, .animal, 460, 315, 0.40, 0.25),
        sound(49, "Golfinho", .nature, .animal, 920, 1_760, 0.36, 0.76),
        sound(50, "Passarinho", .nature, .animal, 1_350, 2_100, 0.31, 0.38),

        sound(51, "Pulso ascendente", .abstract, .abstract, 420, 860, 0.27, 0.18),
        sound(52, "Pulso descendente", .abstract, .abstract, 880, 390, 0.27, 0.32),
        sound(53, "Duas gotas", .abstract, .abstract, 680, 1_080, 0.31, 0.48),
        sound(54, "Eco cristalino", .abstract, .abstract, 760, 1_140, 0.38, 0.64),
        sound(55, "Onda digital", .abstract, .abstract, 280, 720, 0.34, 0.82),
        sound(56, "Clique elástico", .abstract, .abstract, 960, 240, 0.22, 0.94),
        sound(57, "Partícula brilhante", .abstract, .abstract, 920, 1_680, 0.35, 0.38),
        sound(58, "Respiração sintética", .abstract, .abstract, 190, 420, 0.40, 0.55),
        sound(59, "Miniportal", .abstract, .abstract, 240, 1_320, 0.42, 0.74),
        sound(60, "Ressonância do Resenha", .abstract, .abstract, 587.33, 880, 0.36, 0.26),

        sound(61, "Arpa celestial", .angelic, .angelic, 523.25, 1_046.5, 0.42, 0.18),
        sound(62, "Dois sinos suaves", .angelic, .angelic, 659.25, 987.77, 0.39, 0.30),
        sound(63, "Coral ah", .angelic, .angelic, 392, 587.33, 0.43, 0.44),
        sound(64, "Carrilhão de cristal", .angelic, .angelic, 784, 1_318.5, 0.44, 0.58),
        sound(65, "Gota luminosa", .angelic, .angelic, 880, 1_320, 0.31, 0.70),
        sound(66, "Asa delicada", .angelic, .angelic, 440, 698.46, 0.34, 0.82),
        sound(67, "Nuvem sonora", .angelic, .angelic, 349.23, 523.25, 0.45, 0.12),
        sound(68, "Harpa com eco", .angelic, .angelic, 493.88, 987.77, 0.46, 0.36),
        sound(69, "Estrela cintilante", .angelic, .angelic, 1_046.5, 1_568, 0.33, 0.76),
        sound(70, "Sino tibetano suave", .angelic, .angelic, 432, 648, 0.47, 0.92),
    ]

    static var defaultSound: ResenhaSound { sound(id: defaultSoundID)! }
    static func sound(id: Int) -> ResenhaSound? { all.first { $0.id == id } }
    static func sounds(in category: ResenhaSoundCategory) -> [ResenhaSound] {
        all.filter { $0.category == category }
    }

    static func search(_ query: String, in category: ResenhaSoundCategory? = nil) -> [ResenhaSound] {
        let candidates = category.map(sounds(in:)) ?? all
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return candidates }
        return candidates.filter { sound in
            sound.name.localizedStandardContains(normalizedQuery)
                || sound.category.title.localizedStandardContains(normalizedQuery)
                || String(format: "%02d", sound.id).localizedStandardContains(normalizedQuery)
        }
    }

    private static func sound(
        _ id: Int,
        _ name: String,
        _ category: ResenhaSoundCategory,
        _ kind: ResenhaSoundKind,
        _ frequency: Double,
        _ endFrequency: Double,
        _ duration: Double,
        _ character: Double
    ) -> ResenhaSound {
        ResenhaSound(
            id: id,
            name: name,
            category: category,
            kind: kind,
            frequency: frequency,
            endFrequency: endFrequency,
            duration: duration,
            character: character,
            seed: UInt64(id) &* 7_919 &+ 104_729
        )
    }
}

enum ResenhaSoundRenderer {
    static let sampleRate = 44_100

    static func wavData(for preset: ResenhaSound) -> Data {
        let frameCount = max(1, Int(preset.duration * Double(sampleRate)))
        var samples = [Int16]()
        samples.reserveCapacity(frameCount)
        var phase = 0.0
        var secondaryPhase = 0.0
        var noise = SeededNoise(seed: preset.seed)
        var smoothNoise = 0.0

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let position = Double(frame) / Double(max(1, frameCount - 1))
            let frequency = preset.frequency + (preset.endFrequency - preset.frequency) * position
            phase += 2 * .pi * frequency / Double(sampleRate)
            secondaryPhase += 2 * .pi * (frequency * (1.48 + preset.character * 0.72)) / Double(sampleRate)
            let rawNoise = noise.nextSigned()
            smoothNoise = smoothNoise * 0.82 + rawNoise * 0.18
            let attack = min(1, position / 0.035)
            let release = min(1, (1 - position) / 0.16)
            let envelope = attack * release
            let value: Double

            switch preset.kind {
            case .burp:
                let wobble = 0.72 + 0.28 * sin(2 * .pi * (6 + preset.character * 5) * time)
                value = (0.70 * sin(phase) + 0.24 * sin(phase * 0.51) + 0.18 * smoothNoise) * wobble
            case .flatulence:
                let sputter = max(0.18, sin(2 * .pi * (13 + preset.character * 17) * time) * 0.5 + 0.5)
                value = tanh((sin(phase) * 1.7 + smoothNoise * 1.5) * sputter)
            case .breath:
                let pulse = 0.52 + 0.48 * sin(2 * .pi * (3 + preset.character * 9) * time)
                value = smoothNoise * (0.72 + preset.character * 0.24) * pulse + 0.18 * sin(phase)
            case .vocal:
                let vibrato = sin(2 * .pi * (8 + preset.character * 4) * time) * (0.035 + preset.character * 0.025)
                value = 0.66 * sin(phase + vibrato) + 0.24 * sin(phase * 2) + 0.10 * sin(phase * 3)
            case .bell:
                let decay = exp(-position * (3.2 + preset.character * 2.2))
                value = (0.66 * sin(phase) + 0.23 * sin(secondaryPhase) + 0.11 * sin(phase * 3.97)) * decay
            case .percussion:
                let decay = exp(-position * (5.8 + preset.character * 3.2))
                value = (smoothNoise * 0.72 + sin(phase) * 0.52) * decay
            case .retro:
                let steps = floor(position * (2 + preset.character * 4))
                let steppedFrequency = preset.frequency * pow(2, steps / 12)
                let square = sin(2 * .pi * steppedFrequency * time) >= 0 ? 1.0 : -1.0
                value = square * 0.56 + sin(secondaryPhase) * 0.24
            case .animal:
                let modulation = sin(2 * .pi * (9 + preset.character * 19) * time) * (0.2 + preset.character * 0.9)
                let pulse = 0.64 + 0.36 * sin(2 * .pi * (4 + preset.character * 7) * time)
                value = (0.70 * sin(phase + modulation) + 0.20 * sin(phase * 2.01) + 0.10 * smoothNoise) * pulse
            case .abstract:
                let shimmer = sin(secondaryPhase) * (0.16 + preset.character * 0.18)
                let pulse = 0.78 + 0.22 * sin(2 * .pi * (5 + preset.character * 8) * time)
                value = (0.70 * sin(phase) + shimmer + 0.10 * sin(phase * 0.5)) * pulse
            case .angelic:
                let decay = exp(-position * (1.5 + preset.character))
                value = (0.58 * sin(phase) + 0.25 * sin(secondaryPhase) + 0.12 * sin(phase * 2.005)) * decay
            }

            let normalized = max(-1, min(1, value * envelope * 0.68))
            samples.append(Int16(normalized * Double(Int16.max)))
        }

        return makeWAV(samples: samples)
    }

    private static func makeWAV(samples: [Int16]) -> Data {
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36) + dataSize, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(dataSize, to: &data)
        for sample in samples { append(sample, to: &data) }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

private struct SeededNoise {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    mutating func nextSigned() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(UInt64.max >> 11)
        return unit * 2 - 1
    }
}
