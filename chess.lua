local pieceSize = script.Parent.AbsoluteSize.Y / 8

local startingFen = "RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr White"

local alph = {"a", "b", "c", "d", "e", "f", "g", "h"}
local Pieces = {"Pawn", "Bishop", "Knight", "Rook", "King", "Queen", "White", "Black"}

local SelectedPiece = nil

local Turn = nil

local Board = {}

--Yeah im not using nested loops all the time, so i made function instead
function loop(callback)
	for x = 1, 8 do
		for y = 1, 8 do
			callback(Board[x][y], {x, y})
		end
	end
end

---Function to load the board from a fen
function loadFromFen(fen: string)
	--fen is a form of string
	local Types = {
		['k'] = "King",
		['p'] = "Pawn",
		['r'] = "Rook",
		['q'] = "Queen",
		['n'] = "Knight",
		['b'] = "Bishop"
	}

	local xSpot, ySpot = 1, 1
	local fenBoard = string.split(fen, " ")
	fenBoard = fenBoard[1] --our board fen

	Turn = fenBoard[2] -- White starts, determined by fen string.

	for _, row in pairs(string.split(fenBoard, "/")) do
		--we split the fen board by slashes, this gives us a new row that contains pieces
		if tonumber(row) then	
			--- if a whole row is a number,ex: /8/, means row empty, we skip this row, and reset our x to 1
			xSpot = 1
			ySpot += 1
		else
			for symbol in row:gmatch(".") do
				--here we go trough each symbol, which is a chess piece
				if tostring(symbol) then
					--a row can have empty spots, so we check if the symbol is a letter so we can visualize our piece GUI
					local Data = {} -- Each piece contains data: Type, Color, Pos, etc
					local DataType = Types[symbol:lower()] --now we get our piece Type by lowering the symbol and fetching it from table Types
					local DataColor = string.upper(symbol) == symbol and "Black" or "White" --if the symbol lowered is equal to itself, then the color is Black, else its White

					local Size = UDim2.fromOffset(pieceSize, pieceSize)
					local Pos = UDim2.new(0, xSpot * pieceSize - pieceSize, 0, ySpot * pieceSize - pieceSize) -- Simple row and collumn position

					local Click = script.Piece:Clone()
					Click.Size = Size
					Click.Position = Pos
					Click.Parent = script.Parent
					Click.Name = "Click"

					local Piece = game:GetService("ReplicatedStorage").Pieces[DataColor][DataType]:Clone()
					Piece.Size = Size
					Piece.Position = Pos
					Piece.Parent = script.Parent
					Piece.Name = "Piece"

					--// Set Data
					Data["Color"] = DataColor
					Data["Piece"] = Piece
					Data["FirstMove"] = DataType == "Pawn" and true or nil
					Data["ElPessant"] = DataType == "Pawn" and true or false --only pawns have El Passant
					Data["Type"] = DataType
					Data["Click"] = Click --Needed so we can connect to inputbegan later on
					Data["Moves"] = {} -- Piece also contains it's legal moves for later usage
					
					Board[xSpot][ySpot]["Data"] = Data
					
					xSpot += 1 -- we finished off with one symbol, we go on onto next one
				else
					xSpot += 1 -- its a number, meaning its an empty spot / cell, we skip this symbol
				end
			end
			--once row is finished, we go onto next one
			ySpot += 1
			xSpot = 1
		end
	end
	
	--here we loop trough all of cells, connecting a click event
	for x = 1, 8 do
		for y = 1, 8 do
			--we keep track of its row and column inside the data of a cell
			Board[x][y]["X"] = x 
			Board[x][y]["Y"] = y

			local Size = UDim2.fromOffset(pieceSize, pieceSize)
			local Pos = UDim2.new(0, xSpot * pieceSize - pieceSize, 0, ySpot * pieceSize - pieceSize)

			Board[x][y]["Data"]["Click"].InputBegan:Connect(function(inp) -- a cell has been clicked
				if inp.UserInputType.Name ~= 'MouseButton1' then return end

				local ClickedPiece = Board[x][y] -- we get the cell we just clicked
				if SelectedPiece == nil then
					-- if a player hasn't selected any piece, we select the one we clicked
					selectPiece(ClickedPiece)
				else
					-- we have a selected piece already
					if ClickedPiece == SelectedPiece then	
						-- we dont want it to unselect the same piece if u click on it
						return
					end

					if ClickedPiece["Data"]["Color"] == Turn then	
						--if clicked piece belongs to us, we select it
						selectPiece(ClickedPiece)
						return
					end
					
					--all checks passed, we are allowed to move a piece
					MovePiece(SelectedPiece, ClickedPiece)
				end
			end)
		end
	end
end

--Function that calculates legal moves
function PseudoMoves(cell)
	local Moves = {}
	pcall(function()
		--just fetching data
		local pieceData = cell["Data"]
		local pieceType = pieceData["Type"]
		local pieceColor = pieceData["Color"]

		local X, Y = cell["X"], cell["Y"]

		if pieceType == "Pawn" then
			--basic data pawn has
			local FirstMove = pieceData["FirstMove"]
			local firstMoveAddup = FirstMove and 2 or 1 --its against a bot, so -1 offset if piece is going up, 1 if its going down (forward and backward)
			local moveOffset = pieceColor == "White" and - 1 or 1
			local ElPessant = pieceData["ElPessant"]
			
			--we loop trough pawns one cell above to 1 or two above, depending if its a first move
			for y = moveOffset, firstMoveAddup * moveOffset, moveOffset do
				if Board[X][Y + y]["Data"]["Type"] then	
					--piece doesnt capture straight, so we stop the loop if cell above is occupied 
					break
				end
				--inserting legal moves
				table.insert(Moves, Board[X][Y + y])
				pieceData["Moves"] = Moves
			end
			
			--capture calculation from piece left side, checking if piece is not ours then inserting it as a legal move
			if Board[X - 1][Y + 1 * moveOffset]["Data"]["Type"] and not oppPiece(Board[X - 1][Y + 1 * moveOffset]) then	
				table.insert(Moves, Board[X - 1][Y + 1 * moveOffset])
				pieceData["Moves"] = Moves
			end
			
			--capture calculation from piece right side, checking if piece is not ours then inserting it as a legal move
			if Board[X + 1][Y + 1 * moveOffset]["Data"]["Type"] and not oppPiece(Board[X + 1][Y + 1 * moveOffset]) then	
				table.insert(Moves, Board[X + 1][Y + 1 * moveOffset])
				pieceData["Moves"] = Moves
			end
		end
		
		if pieceType == "Knight" then	
			--knight move directions in an L shape
			local spots = {
				{1, -2},
				{-2, 1},
				{2, -1},
				{2, 1},
				{-1, -2},
				{1, 2},
				{-1, 2},
				{-2, -1}
			}
			
			--we loop trough all directions, from a current piece position
			for _, spot in pairs(spots) do
				local x = cell["X"] + spot[1]
				local y = cell["Y"] + spot[2]
				if x>0 and x<9 and y<9 and y>0 and not oppPiece(Board[x][y]) then --basic check out of board bounds and is opponent piece
					table.insert(Moves, Board[x][y])
					pieceData["Moves"] = Moves
				end
			end	
		end
		
		if pieceType == "Rook" then	
			--// X
			for x = X + 1, 8 do
				--basic loop to go from current X spot to 8 (cuz 8x8 board)
				if Board[x][Y]["Data"]["Type"] then	
					if not oppPiece(Board[x][Y]) then --if its opponent piece, we add this cell as legal move for capturing
						table.insert(Moves, Board[x][Y])
						pieceData["Moves"] = Moves
					end
					--our piece, we break the loop and do not add it as legal move
					break
				end
				table.insert(Moves, Board[x][Y])
				pieceData["Moves"] = Moves
			end
			
			--another loop to go from current X pos to 1
			for x = X - 1, 1, -1 do
				if Board[x][Y]["Data"]["Type"] then	
					if not oppPiece(Board[x][Y]) then --if its opponent piece, we add this cell as legal move for capturing
						table.insert(Moves, Board[x][Y])
						pieceData["Moves"] = Moves
					end
					--our piece, we break the loop and do not add it as legal move
					break
				end
				table.insert(Moves, Board[x][Y])
				pieceData["Moves"] = Moves
			end

			--// Y
			-- works same as for x = X loops above, but in Y direction
			for y = Y + 1, 8 do
				if Board[X][y]["Data"]["Type"] then	
					if not oppPiece(Board[X][y]) then	
						table.insert(Moves, Board[X][y])
						pieceData["Moves"] = Moves
					end
					break
				end
				table.insert(Moves, Board[X][y])
				pieceData["Moves"] = Moves
			end

			for y = Y - 1, 1, -1 do
				if Board[X][y]["Data"]["Type"] then	
					if not oppPiece(Board[X][y]) then	
						table.insert(Moves, Board[X][y])
						pieceData["Moves"] = Moves
					end
					break
				end
				table.insert(Moves, Board[X][y])
				pieceData["Moves"] = Moves
			end
		end
		
		if pieceType == "Bishop" then	
			--Diagonal bishop direction
			local Directions = {
				{dx = 1, dy = 1},
				{dx = -1, dy = 1},
				{dx = 1, dy = -1},
				{dx = -1, dy = -1}
			}
			
			
			for _, direction in ipairs(Directions) do
				--here we get diagonal cell by summing up direction X and Y pos with current cell X and Y pos
				local dx = direction.dx
				local dy = direction.dy
				local x = cell["X"] + dx
				local y = cell["Y"] + dy

				while x >= 1 and x <= 8 and y >= 1 and y <= 8 do --while x and y is in bounds of 8x8 board
					if Board[x][y]["Data"]["Type"] then --we check if its not an empty cell
						if not oppPiece(Board[x][y]) then -- check if its opponent piece
							table.insert(Moves, Board[x][y]) --inserting legal moves
							pieceData["Moves"] = Moves
						end
						break
					end
					
					--inserting these empty cells as legal move
					table.insert(Moves, Board[x][y])
					pieceData["Moves"] = Moves

					x = x + dx
					y = y + dy
				end
			end
		end

		if pieceType == "Queen" then	
			--// Bishop Movement
			--explained above
			do 		
				local Directions = {
					{dx = 1, dy = 1},
					{dx = -1, dy = 1},
					{dx = 1, dy = -1},
					{dx = -1, dy = -1}
				}

				for _, direction in ipairs(Directions) do
					local dx = direction.dx
					local dy = direction.dy
					local x = cell["X"] + dx
					local y = cell["Y"] + dy

					while x >= 1 and x <= 8 and y >= 1 and y <= 8 do
						if Board[x][y]["Data"]["Type"] then
							if not oppPiece(Board[x][y]) then	
								table.insert(Moves, Board[x][y])
								pieceData["Moves"] = Moves
							end
							break
						end

						table.insert(Moves, Board[x][y])
						pieceData["Moves"] = Moves

						x = x + dx
						y = y + dy
					end
				end
			end
			--// Rook Mvement
			--explained above
			do
				--// X
				for x = X + 1, 8 do
					if Board[x][Y]["Data"]["Type"] then	
						if not oppPiece(Board[x][Y]) then	
							table.insert(Moves, Board[x][Y])
							pieceData["Moves"] = Moves
						end
						break
					end
					table.insert(Moves, Board[x][Y])
					pieceData["Moves"] = Moves
				end

				for x = X - 1, 1, -1 do
					if Board[x][Y]["Data"]["Type"] then	
						if not oppPiece(Board[x][Y]) then	
							table.insert(Moves, Board[x][Y])
							pieceData["Moves"] = Moves
						end
						break
					end
					table.insert(Moves, Board[x][Y])
					pieceData["Moves"] = Moves
				end

				--// Y
				for y = Y + 1, 8 do
					if Board[X][y]["Data"]["Type"] then	
						if not oppPiece(Board[X][y]) then	
							table.insert(Moves, Board[X][y])
							pieceData["Moves"] = Moves
						end
						break
					end
					table.insert(Moves, Board[X][y])
					pieceData["Moves"] = Moves
				end

				for y = Y - 1, 1, -1 do
					if Board[X][y]["Data"]["Type"] then	
						if not oppPiece(Board[X][y]) then	
							table.insert(Moves, Board[X][y])
							pieceData["Moves"] = Moves
						end
						break
					end
					table.insert(Moves, Board[X][y])
					pieceData["Moves"] = Moves
				end
			end
			--// King Movement
			do
				--neighbours around a cell
				local spots = {
					{-1, -1},
					{-1, 0},
					{-1, 1},
					{0, -1},
					{0, 1},
					{1, 1},
					{1, 0},
					{1, -1}
				}
				
				--looping trough king neigbours 
				for _, spot in ipairs(spots) do
					local x = X + spot[1]
					local y = Y + spot[2]
					if x>0 and x<9 and y<9 and y>0 and not oppPiece(Board[x][y]) then	
						table.insert(Moves, Board[x][y])
						pieceData["Moves"] = Moves	
					end
				end	
			end
		end
		--explained above
		if pieceType == "King" then
			local spots = {
				{-1, -1},
				{-1, 0},
				{-1, 1},
				{0, -1},
				{0, 1},
				{1, 1},
				{1, 0},
				{1, -1}
			}

			for _, spot in ipairs(spots) do
				local x = X + spot[1]
				local y = Y + spot[2]
				if x>0 and x<9 and y<9 and y>0 and not oppPiece(Board[x][y]) then	
					table.insert(Moves, Board[x][y])
					pieceData["Moves"] = Moves	
				end
			end	
		end
	end)
	return Moves
end

--Function that unselects all pieces
function unselectAll()
	loop(function(cell)
		cell["Data"]["Click"].BackgroundTransparency = 1
		cell["Data"]["Click"].Dot.Visible = false
		cell["Data"]["Click"].Corner.Visible = false
	end)
	SelectedPiece = nil
end

--Function to select a provided piece
function selectPiece(piece)
	if piece["Data"]["Type"] and piece["Data"]["Color"] == Turn then --if its not an empty piece we are trying to select and if it belongs to us, we continue with selecting it
		unselectAll() --unselect everything
		piece["Data"]["Click"].BackgroundTransparency = 0
		SelectedPiece = piece
		local Moves = PseudoMoves(SelectedPiece) --here we get legal moves for SelectedPiece
		for i, legalMove in pairs(Moves) do --loop trough em and visualize them
			legalMove["Data"]["Click"].Dot.Visible = true	
			legalMove["Data"]["Click"].Corner.Visible = legalMove["Data"]["Type"] --if its a piece we make a circle around it visible
		end
	end
end

--function to move a piece
function MovePiece(from, to)
	--getting legal moves
	local Moves = PseudoMoves(from)
	if table.find(Moves, to) then --checking if provided cell to move to belongs in legal moves
		--will be used to switch them up
		local oldClone = table.clone(from) --cloning current data
		local newClone = table.clone(to) --cloning to data

		local TimePos

		if to["Data"]["Piece"] ~= nil then	
			to["Data"]["Piece"]:Destroy()
			TimePos	= 8.8
		else
			TimePos = 4.8
		end
		
		--playing capture / move sound as different thread
		coroutine.wrap(function()
			local c = script.Parent.Parent.Parent.Parent["Chess Audio"]:Clone()
			c.Parent = script.Parent
			c.TimePosition = TimePos
			c:Play()
			wait(1)
			c:Destroy()
		end)()
		
		--switching the data of these two cells

		to["Data"]["Type"] = oldClone["Data"]["Type"]
		to["Data"]["Color"] = oldClone["Data"]["Color"]
		to["Data"]["Piece"] = from["Data"]["Piece"]

		from["Data"]["Piece"] = nil
		from["Data"]["Type"] = nil
		from["Data"]["Color"] = nil

		loop(function(cell)
			cell["Data"]["Click"].move.Visible = false
		end)

		from["Data"]["Click"].move.Visible = true
		from["Data"]["Click"].move.BackgroundColor3 = Color3.fromRGB(255, 255, 167)
		to["Data"]["Click"].move.Visible = true
		to["Data"]["Click"].move.BackgroundColor3 = Color3.fromRGB(245, 255, 155)

		local PosToMove = UDim2.new(0, to["X"] * to["Data"]["Piece"].AbsoluteSize.X - to["Data"]["Piece"].AbsoluteSize.X, 0, to["Y"] * to["Data"]["Piece"].AbsoluteSize.Y - to["Data"]["Piece"].AbsoluteSize.Y)

		game:GetService("TweenService"):Create(to["Data"]["Piece"], TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
			Position = PosToMove
		}):Play()

		to["Data"]["FirstMove"] = nil --a piece moved, removing FirstMove
		--checkPromotion(to) to future to add promotion
		Turn = Turn == "White" and "Black" or "White"
	end
	unselectAll()
end

--Function that checks if provided piece is your piece
function oppPiece(piece)
	return Turn == piece["Data"]["Color"]
end

--Displays board GUI without pieces
function displayBoard()
	for x = 1, 8 do
		for y = 1, 8 do
			local Cell = script.Board:Clone()
			Cell.Size = UDim2.fromOffset(pieceSize, pieceSize)
			Cell.Position = UDim2.new(0, x * Cell.AbsoluteSize.X - Cell.AbsoluteSize.X, 0, y * Cell.AbsoluteSize.Y - Cell.AbsoluteSize.Y)
			Cell.Parent = script.Parent
			Cell.Name = alph[x]..9-y
			Cell.BackgroundColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(240, 217, 181) or Color3.fromRGB(181, 136, 99)
			Cell.Spot.Text = alph[x]..9-y
			Cell.Spot.TextColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(199, 179, 150) or Color3.fromRGB(108, 81, 59)

			--Graph
			Cell.OrderNumber.TextColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(108, 81, 59) or Color3.fromRGB(255, 255, 255)
			Cell.OrderNumber.Visible = x == 1 and true or false	
			Cell.OrderNumber.Text = 9-y

			Cell.OrderAlphabetic.TextColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(108, 81, 59) or Color3.fromRGB(255, 255, 255)
			Cell.OrderAlphabetic.Visible = y == 8 and true or false
			Cell.OrderAlphabetic.Text = alph[x]
			
			Cell.Spot.Visible = false
		end
	end
end

--Creates a 8x8 array, we contain our pieces in here.
function create2DArray()
	local Array = {}
	for x = 1, 8 do	
		Array[x] = {}
		for y = 1, 8 do
			local Size = UDim2.fromOffset(pieceSize, pieceSize)
			local Pos = UDim2.new(0, x * pieceSize - pieceSize, 0, y * pieceSize - pieceSize)

			local Click = script.Piece:Clone()
			Click.Size = Size
			Click.Position = Pos
			Click.Parent = script.Parent
			Click.Name = "Click"
			
			Array[x][y] = {X = x, Y = y, SpotName = alph[x]..9-y, Data = {Click = Click}}
		end
	end
	return Array
end

function startGame()
	displayBoard()
	Board = create2DArray()
	loadFromFen(startingFen)
end

startGame()
