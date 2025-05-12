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
    
    enum GameStatus {
        case ongoing, check, checkmate, stalemate
    }
    
    init() {
        setupBoard()
    }
    
    func setupBoard() {
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
        // If a position is already selected
        if let selectedPos = selectedPosition {
            // If the selected position is in possible moves, move the piece
            if possibleMoves.contains(position) {
                // This move has already been validated not to put or leave the king in check
                movePiece(from: selectedPos, to: position)
                selectedPosition = nil
                possibleMoves = []
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
        var castlingMove = false
        if piece.type == .king && abs(from.col - to.col) > 1 {
            castlingMove = true
            // Determine if kingside or queenside castling
            let isKingside = to.col > from.col
            
            // Move the rook as well
            if isKingside {
                // Kingside castling (right)
                let rook = board[from.row][7]
                board[from.row][from.col+1] = rook
                board[from.row][7] = nil
            } else {
                // Queenside castling (left)
                let rook = board[from.row][0]
                board[from.row][from.col-1] = rook
                board[from.row][0] = nil
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
                    
                    // For each potential move, check if it would still leave the king in check
                    for move in moves {
                        if !wouldMoveResultInCheck(from: position, to: move) {
                            hasLegalMoves = true
                            break
                        }
                    }
                    
                    if hasLegalMoves {
                        break
                    }
                }
            }
            
            if hasLegalMoves {
                break
            }
        }
        
        // Update game status
        if isInCheck {
            gameStatus = hasLegalMoves ? .check : .checkmate
        } else {
            gameStatus = hasLegalMoves ? .ongoing : .stalemate
        }
    }
    
    private func isPositionUnderAttack(position: Position, by attackingColor: ChessPieceColor) -> Bool {
        // Check for pawn attacks
        let pawnDirection = attackingColor == .white ? -1 : 1
        for colOffset in [-1, 1] {
            let attackRow = position.row + pawnDirection
            let attackCol = position.col + colOffset
            
            if Position.valid(row: attackRow, col: attackCol),
               let piece = board[attackRow][attackCol],
               piece.type == .pawn && piece.color == attackingColor {
                return true
            }
        }
        
        // Check for knight attacks
        let knightMoves = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        
        for (rowOffset, colOffset) in knightMoves {
            let attackRow = position.row + rowOffset
            let attackCol = position.col + colOffset
            
            if Position.valid(row: attackRow, col: attackCol),
               let piece = board[attackRow][attackCol],
               piece.type == .knight && piece.color == attackingColor {
                return true
            }
        }
        
        // Check for rook and queen attacks (horizontal and vertical)
        let straightDirections = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        for (rowDelta, colDelta) in straightDirections {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color == attackingColor && (piece.type == .rook || piece.type == .queen) {
                        return true
                    }
                    break // Hit a piece, can't check beyond it
                }
                
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
        
        // Check for bishop and queen attacks (diagonal)
        let diagonalDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for (rowDelta, colDelta) in diagonalDirections {
            var currentRow = position.row + rowDelta
            var currentCol = position.col + colDelta
            
            while Position.valid(row: currentRow, col: currentCol) {
                if let piece = board[currentRow][currentCol] {
                    if piece.color == attackingColor && (piece.type == .bishop || piece.type == .queen) {
                        return true
                    }
                    break // Hit a piece, can't check beyond it
                }
                
                currentRow += rowDelta
                currentCol += colDelta
            }
        }
        
        // Check for king attacks (one square in any direction)
        let kingMoves = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1),           (0, 1),
            (1, -1),  (1, 0),  (1, 1)
        ]
        
        for (rowOffset, colOffset) in kingMoves {
            let attackRow = position.row + rowOffset
            let attackCol = position.col + colOffset
            
            if Position.valid(row: attackRow, col: attackCol),
               let piece = board[attackRow][attackCol],
               piece.type == .king && piece.color == attackingColor {
                return true
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

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var game = ChessGame()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                // Status display
                Text("Turn: \(game.currentTurn == .white ? "White" : "Black")")
                    .font(.headline)
                    .padding()
                
                // Chess board
                ChessBoardView(game: game)
                
                // Captured pieces display
                CapturedPiecesView(capturedPieces: game.capturedPieces)
                
                // Status message
                switch game.gameStatus {
                case .check:
                    Text("Check!")
                        .font(.title2)
                        .foregroundColor(.red)
                case .checkmate:
                    Text("Checkmate! \(game.currentTurn.opposite == .white ? "White" : "Black") wins!")
                        .font(.title)
                        .foregroundColor(.green)
                case .stalemate:
                    Text("Stalemate - Draw!")
                        .font(.title)
                        .foregroundColor(.orange)
                case .ongoing:
                    EmptyView()
                }
                
                // New game button
                Button("New Game") {
                    withAnimation {
                        game.board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
                        game.setupBoard()
                        game.currentTurn = .white
                        game.selectedPosition = nil
                        game.possibleMoves = []
                        game.gameStatus = .ongoing
                        game.capturedPieces = []
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.bottom)
            }
            .navigationTitle("Chess")
        }
    }
}

struct ChessBoardView: View {
    @ObservedObject var game: ChessGame
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        ChessCellView(
                            row: row,
                            col: col,
                            piece: game.board[row][col],
                            isSelected: game.selectedPosition?.row == row && game.selectedPosition?.col == col,
                            isPossibleMove: game.possibleMoves.contains(Position(row: row, col: col))
                        )
                        .onTapGesture {
                            game.select(position: Position(row: row, col: col))
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(5)
    }
}

struct ChessCellView: View {
    let row: Int
    let col: Int
    let piece: ChessPiece?
    let isSelected: Bool
    let isPossibleMove: Bool
    
    var body: some View {
        ZStack {
            // Cell background
            Rectangle()
                .fill((row + col) % 2 == 0 ? Color.white : Color.gray.opacity(0.6))
            
            // Selection highlight
            if isSelected {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 3)
            }
            
            // Possible move indicator
            if isPossibleMove {
                Circle()
                    .fill(Color.green.opacity(0.4))
                    .padding(12)
            }
            
            // Piece
            if let piece = piece {
                Text(piece.symbol)
                    .font(.system(size: 30))
                    .foregroundColor(piece.color == .white ? .black : .red)
            }
        }
    }
}

struct CapturedPiecesView: View {
    let capturedPieces: [ChessPiece]
    
    var body: some View {
        HStack {
            // White's captured pieces
            VStack(alignment: .leading) {
                Text("Black captured:")
                    .font(.caption)
                HStack {
                    ForEach(capturedPieces.filter { $0.color == .black }, id: \.symbol) { piece in
                        Text(piece.symbol)
                            .font(.system(size: 20))
                    }
                }
            }
            
            Spacer()
            
            // Black's captured pieces
            VStack(alignment: .trailing) {
                Text("White captured:")
                    .font(.caption)
                HStack {
                    ForEach(capturedPieces.filter { $0.color == .white }, id: \.symbol) { piece in
                        Text(piece.symbol)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .padding()
    }
}

// You can add this view to your existing app structure
// Just import the ContentView where needed
