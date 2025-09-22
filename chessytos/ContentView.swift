import UIKit
import SwiftUI

// MARK: - Trivia Data Structures (from your other game)

struct TriviaQuestion: Codable {
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
}

struct TriviaResponse: Codable {
    let questions: [TriviaQuestion]
}

struct TriviaQuestionWithCategory: Codable {
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
    let category: String
    
    func toTriviaQuestion() -> TriviaQuestion {
        return TriviaQuestion(
            question: question,
            correct_answer: correct_answer,
            incorrect_answers: incorrect_answers
        )
    }
}

struct MultipleChoiceQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int
}

struct TriviaSource {
    let id: String
    let name: String
    let description: String
    let fileResource: String
    let fileExtension: String
    let isOpenTrivia: Bool
}

struct OpenTriviaCategory {
    let id: Int
    let name: String
}

// MARK: - Trivia Source Manager

class TriviaSourceManager: ObservableObject {
    static let shared = TriviaSourceManager()
    
    @Published var availableSources: [TriviaSource] = []
    @Published var selectedOpenTriviaCategories: Set<Int> = []
    
    let availableOpenTriviaCategories: [OpenTriviaCategory] = [
        OpenTriviaCategory(id: 9, name: "General Knowledge"),
        OpenTriviaCategory(id: 17, name: "Science & Nature"),
        OpenTriviaCategory(id: 18, name: "Science: Computers"),
        OpenTriviaCategory(id: 19, name: "Science: Mathematics"),
        OpenTriviaCategory(id: 20, name: "Mythology"),
        OpenTriviaCategory(id: 21, name: "Sports"),
        OpenTriviaCategory(id: 22, name: "Geography"),
        OpenTriviaCategory(id: 23, name: "History"),
        OpenTriviaCategory(id: 24, name: "Politics"),
        OpenTriviaCategory(id: 25, name: "Art"),
        OpenTriviaCategory(id: 26, name: "Celebrities"),
        OpenTriviaCategory(id: 27, name: "Animals"),
        OpenTriviaCategory(id: 28, name: "Vehicles")
    ]
    
    private init() {
        loadDefaultSources()
        loadDefaultCategories()
    }
    
    private func loadDefaultSources() {
        availableSources = [
            TriviaSource(
                id: "opentrivia",
                name: "OpenTrivia Database",
                description: "General trivia questions",
                fileResource: "opentrivia",
                fileExtension: "json",
                isOpenTrivia: true
            )
        ]
    }
    
    private func loadDefaultCategories() {
        // Select first few categories by default
        selectedOpenTriviaCategories = Set([9, 17, 18, 22, 23])
    }
}

// MARK: - Bundle Extension for File Loading

extension Bundle {
    static func loadFile(named fileName: String, withExtension fileExtension: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("❌ Could not find file: \(fileName).\(fileExtension)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("✅ Successfully loaded file: \(fileName).\(fileExtension)")
            return data
        } catch {
            print("❌ Error loading file \(fileName).\(fileExtension): \(error)")
            return nil
        }
    }
}

// MARK: - Chess Game Models (Enhanced)

enum ChessPieceType {
    case pawn, rook, knight, bishop, queen, king
}

enum ChessPieceColor {
    case white, black
    
    var opposite: ChessPieceColor {
        return self == .white ? .black : .white
    }
}

struct ChessPiece: Equatable {
    let type: ChessPieceType
    let color: ChessPieceColor
    var hasMoved = false
    
    var symbol: String {
        switch type {
        case .pawn: return "♟︎"
        case .rook: return "♜"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .queen: return "♛"
        case .king: return "♚"
        }
    }
}

struct Position: Hashable {
    let row: Int
    let col: Int
    
    static func valid(row: Int, col: Int) -> Bool {
        return row >= 0 && row < 8 && col >= 0 && col < 8
    }
}

// MARK: - Enhanced Chess Game Logic with Trivia Integration

class ChessGame: ObservableObject {
    @Published var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var currentTurn: ChessPieceColor = .white
    @Published var selectedPosition: Position? = nil
    @Published var possibleMoves: Set<Position> = []
    @Published var gameStatus: GameStatus = .ongoing
    @Published var capturedPieces: [ChessPiece] = []
    @Published var isComputerThinking: Bool = false
    @Published var kingInCheckPosition: Position? = nil
    
    // MARK: - Timer Properties
    @Published var whiteTimeRemaining: TimeInterval = 180
    @Published var blackTimeRemaining: TimeInterval = 180
    private var gameTimer: Timer?
    
    // MARK: - Trivia Integration Properties
    @Published var showTriviaChallenge: Bool = false
    @Published var pendingMove: (from: Position, to: Position)? = nil
    @Published var triviaEnabled: Bool = true
    @Published var consecutiveCorrectAnswers: Int = 0
    @Published var totalQuestionsAnswered: Int = 0
    
    let playerColor: ChessPieceColor = .white
    let computerColor: ChessPieceColor = .black
    
    enum GameStatus {
        case ongoing, check, checkmate, stalemate
    }
    
    init() {
        setupBoard()
    }
    
    func setupBoard() {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        
        // Setup pawns
        for col in 0..<8 {
            board[1][col] = ChessPiece(type: .pawn, color: .black)
            board[6][col] = ChessPiece(type: .pawn, color: .white)
        }
        
        // Setup rooks
        board[0][0] = ChessPiece(type: .rook, color: .black)
        board[0][7] = ChessPiece(type: .rook, color: .black)
        board[7][0] = ChessPiece(type: .rook, color: .white)
        board[7][7] = ChessPiece(type: .rook, color: .white)
        
        // Setup knights
        board[0][1] = ChessPiece(type: .knight, color: .black)
        board[0][6] = ChessPiece(type: .knight, color: .black)
        board[7][1] = ChessPiece(type: .knight, color: .white)
        board[7][6] = ChessPiece(type: .knight, color: .white)
        
        // Setup bishops
        board[0][2] = ChessPiece(type: .bishop, color: .black)
        board[0][5] = ChessPiece(type: .bishop, color: .black)
        board[7][2] = ChessPiece(type: .bishop, color: .white)
        board[7][5] = ChessPiece(type: .bishop, color: .white)
        
        // Setup queens
        board[0][3] = ChessPiece(type: .queen, color: .black)
        board[7][3] = ChessPiece(type: .queen, color: .white)
        
        // Setup kings
        board[0][4] = ChessPiece(type: .king, color: .black)
        board[7][4] = ChessPiece(type: .king, color: .white)
    }

    func reset() {
        setupBoard()
        currentTurn = .white
        selectedPosition = nil
        possibleMoves = []
        gameStatus = .ongoing
        capturedPieces = []
        isComputerThinking = false
        kingInCheckPosition = nil
        showTriviaChallenge = false
        pendingMove = nil
        consecutiveCorrectAnswers = 0
        totalQuestionsAnswered = 0
        
        // Reset and start timer
        whiteTimeRemaining = 180
        blackTimeRemaining = 180
        stopGameTimer()
        startGameTimer()
    }
    
    // MARK: - Timer Management
    func startGameTimer() {
        stopGameTimer() // Ensure no duplicate timers are running
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // The timer should only run while the game is actively being played
            guard self.gameStatus == .ongoing || self.gameStatus == .check else {
                self.stopGameTimer()
                return
            }
            
            if self.currentTurn == .white {
                if self.whiteTimeRemaining > 0 {
                    self.whiteTimeRemaining -= 1
                }
                if self.whiteTimeRemaining <= 0 {
                    self.whiteTimeRemaining = 0
                    self.gameStatus = .checkmate // Black wins on time
                    self.stopGameTimer()
                }
            } else { // Black's turn
                if self.blackTimeRemaining > 0 {
                    self.blackTimeRemaining -= 1
                }
                if self.blackTimeRemaining <= 0 {
                    self.blackTimeRemaining = 0
                    self.gameStatus = .checkmate // White wins on time
                    self.stopGameTimer()
                }
            }
        }
    }

    func stopGameTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    // MARK: - Enhanced Selection Logic with Trivia Integration
    func select(position: Position) {
        guard currentTurn == playerColor else { return }
        
        if let selectedPos = selectedPosition {
            if possibleMoves.contains(position) {
                // Instead of moving immediately, trigger trivia challenge for human player
                if triviaEnabled && currentTurn == playerColor {
                    pendingMove = (from: selectedPos, to: position)
                    showTriviaChallenge = true
                } else {
                    executePendingMove(from: selectedPos, to: position)
                }
                return
            }
            
            if selectedPos == position {
                selectedPosition = nil
                possibleMoves = []
                return
            }
        }
        
        guard let piece = board[position.row][position.col], piece.color == currentTurn else {
            return
        }
        
        selectedPosition = position
        let allPossibleMoves = getBasicValidMoves(for: position)
        possibleMoves = allPossibleMoves.filter { !wouldMoveResultInCheck(from: position, to: $0) }
    }
    
    // MARK: - Trivia Challenge Callbacks
    func onTriviaSuccess() {
        totalQuestionsAnswered += 1
        consecutiveCorrectAnswers += 1
        
        if let move = pendingMove {
            executePendingMove(from: move.from, to: move.to)
        }
        
        pendingMove = nil
        showTriviaChallenge = false
    }
    
    func onTriviaFailure() {
        totalQuestionsAnswered += 1
        consecutiveCorrectAnswers = 0
        
        // Player loses their turn
        selectedPosition = nil
        possibleMoves = []
        pendingMove = nil
        showTriviaChallenge = false
        
        // Switch to computer turn
        currentTurn = currentTurn.opposite
        
        // Make computer move after a brief delay
        if gameStatus != .checkmate && gameStatus != .stalemate {
            makeComputerMove()
        }
    }
    
    // MARK: - Move Execution
    func executePendingMove(from: Position, to: Position) {
        movePiece(from: from, to: to)
        selectedPosition = nil
        possibleMoves = []
        
        if gameStatus != .checkmate && gameStatus != .stalemate {
            makeComputerMove()
        }
    }
    
    func makeComputerMove() {
        guard currentTurn == computerColor && gameStatus != .checkmate && gameStatus != .stalemate else { return }
        
        isComputerThinking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            var allMoves: [(from: Position, to: Position)] = []
            
            for row in 0..<8 {
                for col in 0..<8 {
                    if let piece = self.board[row][col], piece.color == self.computerColor {
                        let position = Position(row: row, col: col)
                        let validMoves = self.getValidMoves(for: position)
                        
                        for move in validMoves {
                            allMoves.append((from: position, to: move))
                        }
                    }
                }
            }
            
            if let randomMove = allMoves.randomElement() {
                self.movePiece(from: randomMove.from, to: randomMove.to)
            }
            
            self.isComputerThinking = false
        }
    }
    
    // MARK: - Move Validation (keeping existing logic)
    private func getBasicValidMoves(for position: Position) -> Set<Position> {
        guard let piece = board[position.row][position.col] else { return [] }
        
        var validMoves = Set<Position>()
        
        switch piece.type {
        case .pawn:
            getPawnMoves(from: position, color: piece.color, hasMoved: piece.hasMoved, validMoves: &validMoves)
        case .rook:
            getRookMoves(from: position, color: piece.color, validMoves: &validMoves)
        case .knight:
            getKnightMoves(from: position, color: piece.color, validMoves: &validMoves)
        case .bishop:
            getBishopMoves(from: position, color: piece.color, validMoves: &validMoves)
        case .queen:
            getRookMoves(from: position, color: piece.color, validMoves: &validMoves)
            getBishopMoves(from: position, color: piece.color, validMoves: &validMoves)
        case .king:
            getKingMoves(from: position, color: piece.color, validMoves: &validMoves)
        }
        
        return validMoves
    }
    
    func movePiece(from: Position, to: Position) {
        guard let piece = board[from.row][from.col] else { return }
        
        // Handle castling
        if piece.type == .king && abs(from.col - to.col) > 1 {
            let isKingside = to.col > from.col
            
            if isKingside {
                if var rook = board[from.row][7] {
                    rook.hasMoved = true
                    board[from.row][from.col+1] = rook
                    board[from.row][7] = nil
                }
            } else {
                if var rook = board[from.row][0] {
                    rook.hasMoved = true
                    board[from.row][from.col-1] = rook
                    board[from.row][0] = nil
                }
            }
        }
        
        // Handle capture
        if let capturedPiece = board[to.row][to.col] {
            capturedPieces.append(capturedPiece)
        }
        
        var movedPiece = piece
        movedPiece.hasMoved = true
        
        board[to.row][to.col] = movedPiece
        board[from.row][from.col] = nil
        
        // Handle pawn promotion
        if movedPiece.type == .pawn && (to.row == 0 || to.row == 7) {
            board[to.row][to.col] = ChessPiece(type: .queen, color: movedPiece.color)
        }
        
        currentTurn = currentTurn.opposite
        updateGameStatus()
    }
    
    // MARK: - Game Status and Validation (keeping existing logic)
    private func updateGameStatus() {
        var whiteKingPosition: Position?
        var blackKingPosition: Position?
        
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.type == .king {
                    if piece.color == .white {
                        whiteKingPosition = Position(row: row, col: col)
                    } else {
                        blackKingPosition = Position(row: row, col: col)
                    }
                }
            }
        }
        
        guard let whiteKing = whiteKingPosition, let blackKing = blackKingPosition else {
            return
        }
        
        let kingPosition = currentTurn == .white ? whiteKing : blackKing
        let isInCheck = isPositionUnderAttack(position: kingPosition, by: currentTurn.opposite)
        
        var hasLegalMoves = false
        
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == currentTurn {
                    let position = Position(row: row, col: col)
                    let moves = getValidMoves(for: position)
                    
                    if !moves.isEmpty {
                        hasLegalMoves = true
                        break
                    }
                }
            }
            if hasLegalMoves { break }
        }
        
        if isInCheck {
            kingInCheckPosition = kingPosition
            gameStatus = hasLegalMoves ? .check : .checkmate
        } else {
            kingInCheckPosition = nil
            gameStatus = hasLegalMoves ? .ongoing : .stalemate
        }
        
        // Stop the timer if the game has concluded
        if gameStatus == .checkmate || gameStatus == .stalemate {
            stopGameTimer()
        }
    }
    
    private func isPositionUnderAttack(position: Position, by attackingColor: ChessPieceColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == attackingColor {
                    let basicMoves = getBasicValidMoves(for: Position(row: row, col: col))
                    if basicMoves.contains(position) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func wouldMoveResultInCheck(from: Position, to: Position) -> Bool {
        guard let piece = board[from.row][from.col] else { return false }
        
        let targetPiece = board[to.row][to.col]
        
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        var kingPosition: Position?
        for row in 0..<8 {
            for col in 0..<8 {
                if let p = board[row][col], p.type == .king, p.color == piece.color {
                    kingPosition = Position(row: row, col: col)
                    break
                }
            }
            if kingPosition != nil { break }
        }
        
        var wouldBeInCheck = false
        if let kingPos = kingPosition {
            wouldBeInCheck = isPositionUnderAttack(position: kingPos, by: piece.color.opposite)
        }
        
        board[from.row][from.col] = piece
        board[to.row][to.col] = targetPiece
        
        return wouldBeInCheck
    }
    
    func getValidMoves(for position: Position) -> Set<Position> {
        let basicMoves = getBasicValidMoves(for: position)
        return basicMoves.filter { !wouldMoveResultInCheck(from: position, to: $0) }
    }
    
    // MARK: - Piece Movement Logic (keeping existing implementations)
    private func getPawnMoves(from position: Position, color: ChessPieceColor, hasMoved: Bool, validMoves: inout Set<Position>) {
        let direction = color == .white ? -1 : 1
        
        let forwardRow = position.row + direction
        if Position.valid(row: forwardRow, col: position.col) && board[forwardRow][position.col] == nil {
            validMoves.insert(Position(row: forwardRow, col: position.col))
            
            if !hasMoved {
                let doubleForwardRow = position.row + 2 * direction
                if Position.valid(row: doubleForwardRow, col: position.col) && board[doubleForwardRow][position.col] == nil {
                    validMoves.insert(Position(row: doubleForwardRow, col: position.col))
                }
            }
        }
        
        for captureCol in [position.col - 1, position.col + 1] {
            if Position.valid(row: forwardRow, col: captureCol),
               let targetPiece = board[forwardRow][captureCol],
               targetPiece.color != color {
                validMoves.insert(Position(row: forwardRow, col: captureCol))
            }
        }
    }
    
    private func getRookMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        
        for (rowDelta, colDelta) in directions {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color != color {
                        validMoves.insert(Position(row: currentRow, col: currentCol))
                    }
                    break
                }
                
                validMoves.insert(Position(row: currentRow, col: currentCol))
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
    }
    
    private func getKnightMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        let moves = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        
        for (rowDelta, colDelta) in moves {
            let newRow = position.row + rowDelta
            let newCol = position.col + colDelta
            
            if Position.valid(row: newRow, col: newCol) {
                if let piece = board[newRow][newCol] {
                    if piece.color != color {
                        validMoves.insert(Position(row: newRow, col: newCol))
                    }
                } else {
                    validMoves.insert(Position(row: newRow, col: newCol))
                }
            }
        }
    }
    
    private func getBishopMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        let directions = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        
        for (rowDelta, colDelta) in directions {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color != color {
                        validMoves.insert(Position(row: currentRow, col: currentCol))
                    }
                    break
                }
                
                validMoves.insert(Position(row: currentRow, col: currentCol))
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
    }
    
    private func getKingMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        let moves = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1),           (0, 1),
            (1, -1),  (1, 0),  (1, 1)
        ]
        
        for (rowDelta, colDelta) in moves {
            let newRow = position.row + rowDelta
            let newCol = position.col + colDelta
            
            if Position.valid(row: newRow, col: newCol) {
                if let piece = board[newRow][newCol] {
                    if piece.color != color {
                        validMoves.insert(Position(row: newRow, col: newCol))
                    }
                } else {
                    validMoves.insert(Position(row: newRow, col: newCol))
                }
            }
        }
        
        // Castling logic
        if let king = board[position.row][position.col], !king.hasMoved {
            // Kingside castling
            if let rookRight = board[position.row][7],
               rookRight.type == .rook &&
               rookRight.color == color &&
               !rookRight.hasMoved {
                
                let kingsideClear = (position.col+1...6).allSatisfy { board[position.row][$0] == nil }
                
                if kingsideClear {
                    let notInCheck = !isPositionUnderAttack(position: position, by: color.opposite)
                    let passThroughSafe = !isPositionUnderAttack(position: Position(row: position.row, col: position.col+1), by: color.opposite) &&
                    !isPositionUnderAttack(position: Position(row: position.row, col: position.col+2), by: color.opposite)
                    
                    if notInCheck && passThroughSafe {
                        validMoves.insert(Position(row: position.row, col: position.col+2))
                    }
                }
            }
            
            // Queenside castling
            if let rookLeft = board[position.row][0],
               rookLeft.type == .rook &&
               rookLeft.color == color &&
               !rookLeft.hasMoved {
                
                let queensideClear = (1...position.col-1).allSatisfy { board[position.row][$0] == nil }
                
                if queensideClear {
                    let notInCheck = !isPositionUnderAttack(position: position, by: color.opposite)
                    let passThroughSafe = !isPositionUnderAttack(position: Position(row: position.row, col: position.col-1), by: color.opposite) &&
                    !isPositionUnderAttack(position: Position(row: position.row, col: position.col-2), by: color.opposite)
                    
                    if notInCheck && passThroughSafe {
                        validMoves.insert(Position(row: position.row, col: position.col-2))
                    }
                }
            }
        }
    }
}

// MARK: - Chess Trivia Challenge View

struct ChessTriviaChallenge: View {
    @ObservedObject var game: ChessGame
    @Binding var isPresented: Bool
    
    @StateObject private var triviaSourceManager = TriviaSourceManager.shared
    
    // Trivia state
    @State private var triviaQuestion: String = ""
    @State private var options: [String] = []
    @State private var correctAnswer: String = ""
    @State private var selectedAnswer: String?
    @State private var isCorrect: Bool = false
    @State private var hasAnswered: Bool = false
    
    // Timer state
    @State private var timeRemaining: Int = 15
    @State private var timeRemainingPrecise: Double = 15.0
    @State private var timerStartDelay: Double = 1.0
    @State private var timerStarted: Bool = false
    @State private var timerExpired: Bool = false
    private let continuousTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Animation states
    @State private var showFeedback: Bool = false
    
    // Fallback question
    private let fallbackQuestion = "What is the most powerful piece in chess?"
    private let fallbackOptions = ["Queen", "King", "Rook", "Bishop"]
    private let fallbackAnswer = "Queen"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "brain")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text("Chess Challenge")
                                .font(.title2.bold())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color.blue.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        Text("Answer correctly to make your move")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(game.consecutiveCorrectAnswers)")
                                .font(.title2.bold())
                                .foregroundColor(.green)
                            Text("Streak")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack {
                            Text("\(game.totalQuestionsAnswered)")
                                .font(.title2.bold())
                                .foregroundColor(.blue)
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
                    
                    // Timer
                    timerView
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(red: 0.1, green: 0.1, blue: 0.2))
                                .shadow(color: Color.blue.opacity(0.3), radius: 5)
                        )
                        .padding(.horizontal, 20)
                    
                    // Question
                    Text(triviaQuestion.isEmpty ? "Loading question..." : triviaQuestion)
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .frame(minHeight: 120)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(red: 0.1, green: 0.1, blue: 0.2))
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 16)
                    
                    // Options
                    if !options.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    if !hasAnswered && !timerExpired {
                                        selectedAnswer = option
                                        isCorrect = option == correctAnswer
                                        hasAnswered = true
                                        showFeedback = true
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            isPresented = false
                                            if isCorrect {
                                                game.onTriviaSuccess()
                                            } else {
                                                game.onTriviaFailure()
                                            }
                                        }
                                    }
                                }) {
                                    Text(option)
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(getButtonBackgroundColor(for: option))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(getButtonBorderColor(for: option), lineWidth: 2)
                                        )
                                        .foregroundColor(Color.white)
                                }
                                .disabled(hasAnswered || timerExpired)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding()
                    }
                    
                    // Emergency exit button
                    if triviaQuestion.isEmpty {
                        Button(action: {
                            isPresented = false
                            game.onTriviaFailure()
                        }) {
                            Text("Skip Question")
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(red: 0.08, green: 0.08, blue: 0.15))
                            .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 0)
                        
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.8),
                                        Color.purple.opacity(0.6),
                                        Color.blue.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .frame(
                    width: min(geometry.size.width * 0.95, 440),
                    height: min(geometry.size.height * 0.9, 650)
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear {
            loadTriviaQuestion()
            
            timeRemainingPrecise = 15.0
            timeRemaining = 15
            timerExpired = false
            timerStartDelay = 1.0
            timerStarted = false
            
            // Fallback after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if triviaQuestion.isEmpty {
                    triviaQuestion = fallbackQuestion
                    correctAnswer = fallbackAnswer
                    options = fallbackOptions
                }
            }
        }
        .onReceive(continuousTimer) { _ in
            if !hasAnswered && timeRemainingPrecise > 0 {
                if !timerStarted {
                    timerStartDelay -= 0.05
                    if timerStartDelay <= 0 {
                        timerStarted = true
                    }
                } else {
                    timeRemainingPrecise -= 0.05
                    timeRemaining = Int(ceil(timeRemainingPrecise))
                    
                    if timeRemainingPrecise <= 0 {
                        timeRemainingPrecise = 0
                        timerExpired = true
                        hasAnswered = true
                        showFeedback = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPresented = false
                            game.onTriviaFailure()
                        }
                    }
                }
            }
        }
    }
    
    private var timerView: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(getTimerColorSmooth())
                    
                    Text("\(Int(timeRemainingPrecise))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(getTimerColorSmooth())
                }
                
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 10)
                        .foregroundColor(.white.opacity(0.2))
                        .cornerRadius(5)
                    
                    Rectangle()
                        .frame(width: max(0, CGFloat(timeRemainingPrecise) / 15.0 * geometry.size.width), height: 10)
                        .foregroundColor(getTimerColorSmooth())
                        .cornerRadius(5)
                }
            }
            .frame(height: 10)
        }
    }
    
    private func getTimerColorSmooth() -> Color {
        if timeRemainingPrecise > 7.0 {
            let blend = (timeRemainingPrecise - 7.0) / 3.0
            return Color(
                red: 0.3 + (0.3 * (1.0 - blend)),
                green: 0.8,
                blue: 0.3 * (1.0 - blend)
            )
        } else if timeRemainingPrecise > 3.0 {
            let blend = (timeRemainingPrecise - 3.0) / 4.0
            return Color(
                red: 0.9 - (0.6 * blend),
                green: 0.8,
                blue: 0.0
            )
        } else {
            let blend = timeRemainingPrecise / 3.0
            return Color(
                red: 0.9,
                green: 0.8 * blend,
                blue: 0.0
            )
        }
    }
    
    private func getButtonBackgroundColor(for option: String) -> Color {
        if !hasAnswered {
            return Color(red: 0.15, green: 0.15, blue: 0.3)
        } else if option == correctAnswer {
            return Color.green.opacity(0.3)
        } else if option == selectedAnswer {
            return Color.red.opacity(0.3)
        } else {
            return Color(red: 0.15, green: 0.15, blue: 0.3)
        }
    }
    
    private func getButtonBorderColor(for option: String) -> Color {
        if !hasAnswered {
            if option == selectedAnswer {
                return Color.blue.opacity(0.6)
            }
            return Color.clear
        } else if option == correctAnswer {
            return Color.green
        } else if option == selectedAnswer && option != correctAnswer {
            return Color.red
        } else {
            return Color.clear
        }
    }
    
    // MARK: - Trivia Loading Logic
    private func loadTriviaQuestion() {
        print("🎯 Loading trivia question for chess challenge")
        
        let selectedCategoryIds = triviaSourceManager.selectedOpenTriviaCategories
        let availableCategories = triviaSourceManager.availableOpenTriviaCategories.filter {
            selectedCategoryIds.contains($0.id)
        }
        
        if availableCategories.isEmpty {
            loadFromDefaultSource()
            return
        }
        
        loadFromOpenTrivia(availableCategories)
    }
    
    private func loadFromOpenTrivia(_ categories: [OpenTriviaCategory]) {
        guard !categories.isEmpty else {
            loadFromDefaultSource()
            return
        }
        
        let source = triviaSourceManager.availableSources.first { $0.isOpenTrivia }
        guard let openTriviaSource = source else {
            print("❌ No OpenTrivia source found")
            return
        }
        
        print("🎯 Loading OpenTrivia questions for categories: \(categories.map { $0.name })")
        
        guard let data = Bundle.loadFile(named: openTriviaSource.fileResource, withExtension: openTriviaSource.fileExtension) else {
            print("❌ Failed to load OpenTrivia data")
            loadFromDefaultSource()
            return
        }
        
        guard let questionsWithCategories = decodeQuestionsWithCategories(from: data) else {
            print("❌ Failed to decode questions with categories")
            loadFromDefaultSource()
            return
        }
        
        print("✅ Loaded \(questionsWithCategories.count) total questions")
        
        let selectedCategoryNames = Set(categories.map { $0.name })
        let filteredQuestions = questionsWithCategories.filter { question in
            selectedCategoryNames.contains(question.category)
        }
        
        print("🎯 Filtered to \(filteredQuestions.count) questions from selected categories")
        
        if filteredQuestions.isEmpty {
            print("⚠️ No questions found for selected categories")
            if let randomQuestion = questionsWithCategories.randomElement() {
                print("🔄 Using fallback question from: \(randomQuestion.category)")
                setQuestion(randomQuestion.toTriviaQuestion())
            } else {
                loadFromDefaultSource()
            }
        } else {
            if let randomQuestion = filteredQuestions.randomElement() {
                print("✅ Selected question from category: \(randomQuestion.category)")
                setQuestion(randomQuestion.toTriviaQuestion())
            } else {
                loadFromDefaultSource()
            }
        }
    }
    
    private func decodeQuestionsWithCategories(from data: Data) -> [TriviaQuestionWithCategory]? {
        do {
            let questions = try JSONDecoder().decode([TriviaQuestionWithCategory].self, from: data)
            print("✅ Decoded as TriviaQuestionWithCategory array with \(questions.count) questions")
            return questions
        } catch {
            print("❌ TriviaQuestionWithCategory decode failed: \(error)")
            return nil
        }
    }
    
    private func loadFromDefaultSource() {
        print("🎯 Loading from default fallback source")
        
        let fallbackSource = triviaSourceManager.availableSources.first ?? TriviaSource(
            id: "fallback",
            name: "General Knowledge",
            description: "Fallback questions",
            fileResource: "opentrivia",
            fileExtension: "json",
            isOpenTrivia: true
        )
        
        guard let data = Bundle.loadFile(named: fallbackSource.fileResource, withExtension: fallbackSource.fileExtension) else {
            print("❌ Even fallback source failed to load")
            return
        }
        
        if let questions = decodeQuestions(from: data) {
            if let randomQuestion = questions.randomElement() {
                setQuestion(randomQuestion)
            }
        }
    }
    
    private func decodeQuestions(from data: Data) -> [TriviaQuestion]? {
        do {
            let response = try JSONDecoder().decode(TriviaResponse.self, from: data)
            print("✅ Decoded as TriviaResponse format with \(response.questions.count) questions")
            return response.questions
        } catch {
            print("⚠️ TriviaResponse decode failed: \(error)")
        }
        
        do {
            let questions = try JSONDecoder().decode([TriviaQuestion].self, from: data)
            print("✅ Decoded as direct TriviaQuestion array with \(questions.count) questions")
            return questions
        } catch {
            print("❌ Direct TriviaQuestion array decode failed: \(error)")
        }
        
        return nil
    }
    
    private func setQuestion(_ question: TriviaQuestion) {
        triviaQuestion = question.question
        correctAnswer = question.correct_answer
        options = (question.incorrect_answers + [question.correct_answer]).shuffled()
        print("🎯 Question set: \(triviaQuestion.prefix(50))...")
        print("🎯 Options count: \(options.count)")
    }
}

// MARK: - Liquid Glass Visual Effects (keeping existing)

struct LiquidGlassEffect: ViewModifier {
    let intensity: Double
    let tint: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .clear,
                                        .black.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            )
    }
}

extension View {
    func liquidGlass(intensity: Double = 1.0, tint: Color? = nil) -> some View {
        self.modifier(LiquidGlassEffect(intensity: intensity, tint: tint))
    }
}

// MARK: - Player Info View (Timer and Captured Pieces)

struct PlayerInfoView: View {
    var color: ChessPieceColor
    var timeRemaining: TimeInterval
    var capturedPieces: [ChessPiece]
    @ObservedObject var game: ChessGame

    private func formatTime(_ totalSeconds: TimeInterval) -> String {
        let seconds = Int(ceil(totalSeconds))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    var body: some View {
        HStack {
            if color == .white {
                // For the white player (bottom), show captured pieces on the left
                CapturedPiecesView(pieces: capturedPieces)
                Spacer()
                timerDisplay
            } else {
                // For the black player (top), show timer on the left
                timerDisplay
                Spacer()
                CapturedPiecesView(pieces: capturedPieces)
            }
        }
        .padding(.horizontal)
    }
    
    private var timerDisplay: some View {
        Text(formatTime(timeRemaining))
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundColor(timeRemaining < 10 && timeRemaining > 0 ? .red : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                // Highlight the timer for the active player
                game.currentTurn == color && game.gameStatus != .checkmate && game.gameStatus != .stalemate ?
                Color.blue.opacity(0.4) : Color.black.opacity(0.3)
            )
            .cornerRadius(10)
            .animation(.easeInOut, value: game.currentTurn)
    }
}


// MARK: - Main Content View (Enhanced)

struct ContentView: View {
    @StateObject private var game = ChessGame()
    @State private var backgroundOffset: CGSize = .zero
    
    var dynamicBackground: some View {
        ZStack {
            LinearGradient(
                colors: gameBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .offset(
                        x: CGFloat(index * 80 - 200) + backgroundOffset.width * 0.1,
                        y: CGFloat(index * 60 - 150) + backgroundOffset.height * 0.1
                    )
                    .animation(
                        .easeInOut(duration: 3 + Double(index) * 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: backgroundOffset
                    )
            }
        }
        .onAppear {
            backgroundOffset = CGSize(width: 20, height: 30)
        }
    }
    
    var gameBackgroundColors: [Color] {
        switch game.gameStatus {
        case .checkmate:
            return [
                Color(red: 0.4, green: 0.6, blue: 1.0),
                Color(red: 0.6, green: 0.4, blue: 0.9),
                Color(red: 0.5, green: 0.7, blue: 0.95)
            ]
        default:
            return [
                Color(red: 0.1, green: 0.15, blue: 0.25),
                Color(red: 0.15, green: 0.2, blue: 0.3),
                Color(red: 0.08, green: 0.12, blue: 0.22)
            ]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                dynamicBackground
                
                VStack(spacing: 10) {
                    statusCard
                    
                    // Black Player Info (Top)
                    PlayerInfoView(
                        color: .black,
                        timeRemaining: game.blackTimeRemaining,
                        capturedPieces: game.capturedPieces.filter { $0.color == .white },
                        game: game
                    )
                    
                    ChessBoardView(game: game)
                        .liquidGlass()
                        .scaleEffect(game.gameStatus == .checkmate ? 1.02 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: game.gameStatus)
                    
                    // White Player Info (Bottom)
                    PlayerInfoView(
                        color: .white,
                        timeRemaining: game.whiteTimeRemaining,
                        capturedPieces: game.capturedPieces.filter { $0.color == .black },
                        game: game
                    )
                    
                    Spacer(minLength: 10)
                    
                    gameControls
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Chess with Trivia")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Start a new game and timer when the view first appears
                game.reset()
            }
        }
        .fullScreenCover(isPresented: $game.showTriviaChallenge) {
            ChessTriviaChallenge(game: game, isPresented: $game.showTriviaChallenge)
        }
    }
    
    var statusCard: some View {
        VStack(spacing: 8) {
            if game.gameStatus == .checkmate {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    
                    let winnerText = game.currentTurn.opposite == .white ? "White" : "Black"
                    let reasonText = (game.whiteTimeRemaining <= 0 || game.blackTimeRemaining <= 0) ? "on Time" : "by Checkmate"

                    Text("Victory for \(winnerText) \(reasonText)!")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }
                .font(.title3)
            } else if game.gameStatus == .stalemate {
                Text("Stalemate - Draw!")
                    .font(.title3)
                    .fontWeight(.semibold)
            } else if game.gameStatus == .check {
                Text("Check")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            } else {
                HStack(spacing: 8) {
                    Text(game.currentTurn == .white ? "White's Turn" : "Black's Turn")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if game.isComputerThinking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Trivia stats
            if game.totalQuestionsAnswered > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .foregroundColor(.blue)
                        Text("Streak: \(game.consecutiveCorrectAnswers)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.green)
                        Text("Total: \(game.totalQuestionsAnswered)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 30)
        .liquidGlass()
    }
    
    var gameControls: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    resetGame()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("New Game")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .foregroundColor(.primary)
            .scaleEffect(game.gameStatus == .checkmate ? 1.1 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: game.gameStatus)
            
            Button(action: {
                game.triviaEnabled.toggle()
            }) {
                HStack {
                    Image(systemName: game.triviaEnabled ? "brain.head.profile" : "brain.head.profile.fill")
                    Text(game.triviaEnabled ? "Trivia ON" : "Trivia OFF")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    game.triviaEnabled ?
                    Color.blue.opacity(0.2) : Color.gray.opacity(0.2),
                    in: RoundedRectangle(cornerRadius: 25)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            game.triviaEnabled ? Color.blue.opacity(0.6) : Color.gray.opacity(0.6),
                            lineWidth: 1
                        )
                )
            }
            .foregroundColor(game.triviaEnabled ? .blue : .gray)
        }
    }
    
    func resetGame() {
        game.reset()
    }
}

// MARK: - Chess Board and Cell Views (MODIFIED)

struct ChessBoardView: View {
    @ObservedObject var game: ChessGame
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 8.0
            
            VStack(spacing: 0) { // Set spacing to 0 for a seamless grid
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) { // Set spacing to 0 for a seamless grid
                        ForEach(0..<8, id: \.self) { col in
                            ChessCellView(
                                game: game,
                                row: row,
                                col: col,
                                piece: game.board[row][col],
                                isSelected: game.selectedPosition?.row == row && game.selectedPosition?.col == col,
                                isPossibleMove: game.possibleMoves.contains(Position(row: row, col: col)),
                                isKingInCheck: game.kingInCheckPosition == Position(row: row, col: col),
                                size: cellSize // Pass calculated size
                            )
                            .frame(width: cellSize, height: cellSize)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    game.select(position: Position(row: row, col: col))
                                }
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(8) // Reduced padding to make board bigger
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
}

struct ChessPieceView: View {
    let piece: ChessPiece
    let size: CGFloat

    var body: some View {
        ZStack {
            Text(piece.symbol)
                .font(.system(size: size, weight: .black, design: .default))
                .foregroundColor(.black.opacity(0.3))
                .offset(x: 2, y: 2)
                .blur(radius: 1)
        
            Text(piece.symbol)
                .font(.system(size: size, weight: .black, design: .default))
                .foregroundColor(piece.color == .white ? .white : .black)
                .overlay(
                    Text(piece.symbol)
                        .font(.system(size: size, weight: .black, design: .default))
                        .foregroundColor(.white.opacity(0.6))
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
        }
    }
}

struct ChessCellView: View {
    @ObservedObject var game: ChessGame
    let row: Int
    let col: Int
    let piece: ChessPiece?
    let isSelected: Bool
    let isPossibleMove: Bool
    let isKingInCheck: Bool
    let size: CGFloat // Add size property
    
    var cellBaseColor: Color {
        (row + col) % 2 == 0 ?
        Color(red: 0.8, green: 0.82, blue: 0.85) :
        Color(red: 0.5, green: 0.55, blue: 0.6)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellBaseColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .clear,
                                    .black.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            if isKingInCheck {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 3)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.cyan.opacity(0.6),
                                Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .scaleEffect(1.05)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
            
            if isPossibleMove {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.6, green: 0.85, blue: 0.95), lineWidth: 2)
                    .shadow(color: Color(red: 0.6, green: 0.85, blue: 0.95), radius: 3, x: 0, y: 0)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: isPossibleMove)
            }
            
            if let piece = piece {
                ChessPieceView(piece: piece, size: size * 0.8) // Use relative size
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
        }
    }
}

struct CapturedPiecesView: View {
    let pieces: [ChessPiece]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                ChessPieceView(piece: piece, size: 24.2)
                    .opacity(0.8)
            }
        }
        .frame(height: 25)
    }
}
