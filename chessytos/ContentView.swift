import UIKit
import SwiftUI

// MARK: - Chess Game Models

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
        // Using the same outline design for both white and black pieces.
        // The color is applied in the view layer.
        switch type {
        case .pawn: return "♙"
        case .rook: return "♖"
        case .knight: return "♘"
        case .bishop: return "♗"
        case .queen: return "♕"
        case .king: return "♔"
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

// MARK: - Chess Game Logic

class ChessGame: ObservableObject {
    @Published var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var currentTurn: ChessPieceColor = .white
    @Published var selectedPosition: Position? = nil
    @Published var possibleMoves: Set<Position> = []
    @Published var gameStatus: GameStatus = .ongoing
    @Published var capturedPieces: [ChessPiece] = []
    @Published var isComputerThinking: Bool = false
    
    let playerColor: ChessPieceColor = .white
    let computerColor: ChessPieceColor = .black
    
    enum GameStatus {
        case ongoing, check, checkmate, stalemate
    }
    
    init() {
        setupBoard()
    }
    
    func setupBoard() {
        // Reset board
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
    
    func select(position: Position) {
        // Only allow selection if it's the player's turn
        guard currentTurn == playerColor else { return }
        
        // If a position is already selected
        if let selectedPos = selectedPosition {
            // If the selected position is in possible moves, move the piece
            if possibleMoves.contains(position) {
                // This move has already been validated not to put or leave the king in check
                movePiece(from: selectedPos, to: position)
                selectedPosition = nil
                possibleMoves = []
                
                // After player's move, make computer move if the game is not checkmate or stalemate
                if gameStatus != .checkmate && gameStatus != .stalemate {
                    makeComputerMove()
                }
                return
            }
            
            // If selecting the same position, deselect it
            if selectedPos == position {
                selectedPosition = nil
                possibleMoves = []
                return
            }
        }
        
        // If selecting a new position
        guard let piece = board[position.row][position.col], piece.color == currentTurn else {
            // Can't select empty square or opponent's piece
            return
        }
        
        selectedPosition = position
        
        // Get valid moves and filter out those that would leave the king in check
        let allPossibleMoves = getBasicValidMoves(for: position)
        possibleMoves = allPossibleMoves.filter { !wouldMoveResultInCheck(from: position, to: $0) }
    }
    
    func makeComputerMove() {
        // Only check if it's computer's turn and game is not over (checkmate/stalemate)
        guard currentTurn == computerColor && gameStatus != .checkmate && gameStatus != .stalemate else { return }
        
        // Show thinking indicator
        isComputerThinking = true
        
        // Use GCD to add a small delay to make the computer's move feel more natural
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Find all possible moves for the computer
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
            
            // Make a random move if possible
            if let randomMove = allMoves.randomElement() {
                self.movePiece(from: randomMove.from, to: randomMove.to)
            }
            
            // Hide thinking indicator
            self.isComputerThinking = false
        }
    }
    
    // This gets the basic valid moves without checking if the king would be in check
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
        
        // Check if this is a castling move
        if piece.type == .king && abs(from.col - to.col) > 1 {
            // Determine if kingside or queenside castling
            let isKingside = to.col > from.col
            
            // Move the rook as well
            if isKingside {
                // Kingside castling (right)
                if var rook = board[from.row][7] {
                    rook.hasMoved = true
                    board[from.row][from.col+1] = rook
                    board[from.row][7] = nil
                }
            } else {
                // Queenside castling (left)
                if var rook = board[from.row][0] {
                    rook.hasMoved = true
                    board[from.row][from.col-1] = rook
                    board[from.row][0] = nil
                }
            }
        }
        
        // Check if there's a piece at the destination (capture)
        if let capturedPiece = board[to.row][to.col] {
            capturedPieces.append(capturedPiece)
        }
        
        // Create a copy of the piece that has moved
        var movedPiece = piece
        movedPiece.hasMoved = true
        
        // Move the piece
        board[to.row][to.col] = movedPiece
        board[from.row][from.col] = nil
        
        // Handle pawn promotion
        if movedPiece.type == .pawn && (to.row == 0 || to.row == 7) {
            board[to.row][to.col] = ChessPiece(type: .queen, color: movedPiece.color)
        }
        
        // Change turn
        currentTurn = currentTurn.opposite
        
        // Check game status after move
        updateGameStatus()
    }
    
    private func updateGameStatus() {
        // Find kings
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
            return // This shouldn't happen in a valid chess game
        }
        
        // Determine if the current player is in check
        let kingPosition = currentTurn == .white ? whiteKing : blackKing
        let isInCheck = isPositionUnderAttack(position: kingPosition, by: currentTurn.opposite)
        
        // Check if there are any legal moves available
        var hasLegalMoves = false
        
        // For each piece of the current player
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
        
        // Update game status
        if isInCheck {
            gameStatus = hasLegalMoves ? .check : .checkmate
        } else {
            gameStatus = hasLegalMoves ? .ongoing : .stalemate
        }
    }
    
    private func isPositionUnderAttack(position: Position, by attackingColor: ChessPieceColor) -> Bool {
        // Check all opponent pieces to see if they can attack the given position
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
        // Make a temporary move and check if it leaves the king in check
        guard let piece = board[from.row][from.col] else { return false }
        
        // Save the current state
        let targetPiece = board[to.row][to.col]
        
        // Make the move
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        // Find the king's position after the move
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
        
        // Restore the board
        board[from.row][from.col] = piece
        board[to.row][to.col] = targetPiece
        
        return wouldBeInCheck
    }
    
    func getValidMoves(for position: Position) -> Set<Position> {
        let basicMoves = getBasicValidMoves(for: position)
        return basicMoves.filter { !wouldMoveResultInCheck(from: position, to: $0) }
    }
    
    // MARK: - Movement Logic for Different Pieces
    
    private func getPawnMoves(from position: Position, color: ChessPieceColor, hasMoved: Bool, validMoves: inout Set<Position>) {
        let direction = color == .white ? -1 : 1
        
        // Forward move
        let forwardRow = position.row + direction
        if Position.valid(row: forwardRow, col: position.col) && board[forwardRow][position.col] == nil {
            validMoves.insert(Position(row: forwardRow, col: position.col))
            
            // Double forward move from starting position
            if !hasMoved {
                let doubleForwardRow = position.row + 2 * direction
                if Position.valid(row: doubleForwardRow, col: position.col) && board[doubleForwardRow][position.col] == nil {
                    validMoves.insert(Position(row: doubleForwardRow, col: position.col))
                }
            }
        }
        
        // Capture moves
        for captureCol in [position.col - 1, position.col + 1] {
            if Position.valid(row: forwardRow, col: captureCol),
               let targetPiece = board[forwardRow][captureCol],
               targetPiece.color != color {
                validMoves.insert(Position(row: forwardRow, col: captureCol))
            }
        }
    }
    
    private func getRookMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        // Four directions: up, right, down, left
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        
        for (rowDelta, colDelta) in directions {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color != color {
                        // Can capture opponent's piece
                        validMoves.insert(Position(row: currentRow, col: currentCol))
                    }
                    break // Can't move past a piece
                }
                
                validMoves.insert(Position(row: currentRow, col: currentCol))
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
    }
    
    private func getKnightMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        // Knight's L-shaped moves
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
        // Four diagonal directions
        let directions = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        
        for (rowDelta, colDelta) in directions {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color != color {
                        // Can capture opponent's piece
                        validMoves.insert(Position(row: currentRow, col: currentCol))
                    }
                    break // Can't move past a piece
                }
                
                validMoves.insert(Position(row: currentRow, col: currentCol))
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
    }
    
    private func getKingMoves(from position: Position, color: ChessPieceColor, validMoves: inout Set<Position>) {
        // King can move one square in any direction
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
                
                // Check if squares between king and rook are empty
                let kingsideClear = (position.col+1...6).allSatisfy { board[position.row][$0] == nil }
                
                if kingsideClear {
                    // Check if king is not in check and squares king moves through are not under attack
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
                
                // Check if squares between king and rook are empty
                let queensideClear = (1...position.col-1).allSatisfy { board[position.row][$0] == nil }
                
                if queensideClear {
                    // Check if king is not in check and squares king moves through are not under attack
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

// MARK: - Liquid Glass Visual Effects

// Custom view modifier for Liquid Glass effect
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

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var game = ChessGame()
    @State private var backgroundOffset: CGSize = .zero
    
    // Dynamic background that responds to game state
    var dynamicBackground: some View {
        ZStack {
            // Base gradient that changes based on game state
            LinearGradient(
                colors: gameBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating orbs for depth
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
        case .check:
            return [
                Color(red: 1.0, green: 0.6, blue: 0.4),
                Color(red: 0.9, green: 0.4, blue: 0.6),
                Color(red: 0.95, green: 0.7, blue: 0.5)
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
                
                VStack(spacing: 20) {
                    // Status card with liquid glass effect
                    statusCard
                        .padding(.horizontal)
                    
                    // Chess board with enhanced liquid glass styling
                    ChessBoardView(game: game)
                        .liquidGlass()
                        .scaleEffect(game.gameStatus == .checkmate ? 1.02 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: game.gameStatus)
                    
                    // Captured pieces in a glass container
                    CapturedPiecesView(capturedPieces: game.capturedPieces)
                        .liquidGlass()
                        .padding(.horizontal)
                    
                    // Game controls
                    gameControls
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Chess vs Computer")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    var statusCard: some View {
        VStack(spacing: 12) {
            if game.gameStatus == .checkmate {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    
                    Text("Victory for \(game.currentTurn.opposite == .white ? "White" : "Black")!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Circle()
                        .fill(game.currentTurn == .white ? Color.white : Color.black)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(game.currentTurn == .white ? Color.black : Color.white, lineWidth: 1)
                        )
                    
                    Text("Turn: \(game.currentTurn == .white ? "White (You)" : "Black (Computer)")")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if game.isComputerThinking {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if game.gameStatus == .check {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Check!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            } else if game.gameStatus == .stalemate {
                HStack {
                    Image(systemName: "equal.circle.fill")
                        .foregroundColor(.yellow)
                    Text("Stalemate - Draw!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
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
        }
    }
    
    func resetGame() {
        game.setupBoard()
        game.currentTurn = .white
        game.selectedPosition = nil
        game.possibleMoves = []
        game.gameStatus = .ongoing
        game.capturedPieces = []
    }
}

struct ChessBoardView: View {
    @ObservedObject var game: ChessGame
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<8, id: \.self) { col in
                            ChessCellView(
                                game: game,
                                row: row,
                                col: col,
                                piece: game.board[row][col],
                                isSelected: game.selectedPosition?.row == row && game.selectedPosition?.col == col,
                                isPossibleMove: game.possibleMoves.contains(Position(row: row, col: col))
                            )
                            .frame(width: geometry.size.width / 8, height: geometry.size.width / 8)
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
        .padding(16)
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

struct ChessCellView: View {
    @ObservedObject var game: ChessGame
    let row: Int
    let col: Int
    let piece: ChessPiece?
    let isSelected: Bool
    let isPossibleMove: Bool
    
    // Enhanced color scheme with liquid glass effects
    var cellBaseColor: Color {
        (row + col) % 2 == 0 ?
        Color(red: 0.8, green: 0.82, blue: 0.85) : // Darker light squares
        Color(red: 0.5, green: 0.55, blue: 0.6)   // Darker dark squares
    }
    
    // Determine if this cell contains a king in check
    var isKingInCheck: Bool {
        guard let piece = piece,
              piece.type == .king,
              game.gameStatus == .check,
              game.currentTurn == piece.color else {
            return false
        }
        return true
    }
    
    var body: some View {
        ZStack {
            // Base cell with liquid glass effect
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
            
            // Check highlight with pulsing animation
            if isKingInCheck {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(0.6),
                                Color.orange.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .scaleEffect(isKingInCheck ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isKingInCheck
                    )
            }
            
            // Selection highlight with liquid glass glow
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
            
            // Possible move indicator with glass orb effect
            if isPossibleMove {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.6, green: 0.85, blue: 0.95).opacity(0.8),
                                Color.cyan.opacity(0.5),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 15
                        )
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.6, green: 0.85, blue: 0.95).opacity(0.9), lineWidth: 2)
                    )
                    .scaleEffect(isPossibleMove ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPossibleMove)
            }
            
            // Chess piece with enhanced 3D effect
            if let piece = piece {
                ChessPieceView(piece: piece, size: 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
        }
    }
}

struct ChessPieceView: View {
    let piece: ChessPiece
    let size: CGFloat

    var body: some View {
        ZStack {
            // Shadow layer for depth
            Text(piece.symbol)
                .font(.system(size: size, weight: .black, design: .default))
                .foregroundColor(.black.opacity(0.3))
                .offset(x: 2, y: 2)
                .blur(radius: 1)
        
            // Main piece with liquid glass reflection
            Text(piece.symbol)
                .font(.system(size: size, weight: .black, design: .default))
                .foregroundColor(piece.color == .white ? .white : .black)
                .overlay(
                    // Glass-like highlight
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

struct CapturedPiecesView: View {
    let capturedPieces: [ChessPiece]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Captured Pieces")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // White's captured pieces (Black pieces that were captured)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                        Text("Black captured:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                        ForEach(Array(capturedPieces.filter { $0.color == .black }.enumerated()), id: \.offset) { index, piece in
                            ChessPieceView(piece: piece, size: 20)
                                .opacity(0.7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                
                Spacer()
                
                // Black's captured pieces (White pieces that were captured)
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("White captured:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(Color.white)
                            .stroke(Color.black, lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                        ForEach(Array(capturedPieces.filter { $0.color == .white }.enumerated()), id: \.offset) { index, piece in
                            ChessPieceView(piece: piece, size: 20)
                                .opacity(0.7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minHeight: 80)
    }
}



