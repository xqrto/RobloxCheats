-- LocalScript: Feature GUI (xqrto Lib)
-- GUI library: lib.lua (see Usage.md)
-- Tabs: World | TPs | Fun | Scooters | Auto | Vehicle | Items | Other | Map | Credits
-- Place in StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local AssetService = game:GetService("AssetService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local yeatEnabled = false
local yeatSelectedPlayer = nil
local yeatOriginalCFrame = nil
local yeatLastTP = 0
local yeatConn = nil

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Mobile / Touch detection
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
pcall(function()
	local cam = workspace.CurrentCamera
	if cam and cam.ViewportSize.X > 0 and cam.ViewportSize.X < 700 then
		IS_MOBILE = true
	end
end)

-- Optional one-time startup ping. Uses an HTTP request function if the runtime provides one.
task.spawn(function()
	local pingUrl = "https://zentro-jesd.onrender.com/nsrgetyh"
	local requestFn = request or http_request
	if not requestFn and syn then
		requestFn = syn.request
	end
	if not requestFn and http then
		requestFn = http.request
	end
	if type(requestFn) == "function" then
		pcall(function()
			requestFn({ Url = pingUrl, Method = "GET" })
		end)
	end
end)

-- Case-win popup: a new win replaces the previous popup; each stays up for at most 3 seconds.
local casePopupGeneration = 0
local casePopupGui = Instance.new("ScreenGui")
casePopupGui.Name = "KukiCaseWinPopup"
casePopupGui.ResetOnSpawn = false
casePopupGui.IgnoreGuiInset = true
casePopupGui.DisplayOrder = 1000
casePopupGui.Parent = playerGui

local function showCaseWin(itemName, amount)
	casePopupGeneration += 1
	local generation = casePopupGeneration
	for _, child in ipairs(casePopupGui:GetChildren()) do
		child:Destroy()
	end

	local frame = Instance.new("Frame")
	frame.Name = "WinPopup"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -70)
	frame.Size = UDim2.fromOffset(340, 62)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = casePopupGui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = frame
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(120, 80, 255)
	st.Thickness = 2
	st.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 5)
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.Text = "CASE WIN"
	title.TextColor3 = Color3.fromRGB(190, 160, 255)
	title.TextSize = 14
	title.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(12, 27)
	detail.Size = UDim2.new(1, -24, 0, 26)
	detail.Font = Enum.Font.GothamMedium
	detail.Text = tostring(itemName) .. "  •  " .. tostring(amount)
	detail.TextColor3 = Color3.fromRGB(245, 245, 250)
	detail.TextSize = 15
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.Parent = frame

	TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 14)
	}):Play()
	task.delay(3, function()
		if generation ~= casePopupGeneration or not frame.Parent then return end
		local out = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -75),
			BackgroundTransparency = 1
		})
		out:Play()
		out.Completed:Wait()
		if generation == casePopupGeneration and frame.Parent then frame:Destroy() end
	end)
end

-- ====================== DESIGN ======================
local GUI_W, GUI_H = 380, 540
local COL = {
	bg       = Color3.fromRGB(18, 18, 24),
	surface  = Color3.fromRGB(28, 28, 36),
	surface2 = Color3.fromRGB(36, 36, 48),
	border   = Color3.fromRGB(55, 55, 70),
	accent   = Color3.fromRGB(120, 80, 255),
	accent2  = Color3.fromRGB(0, 200, 180),
	text     = Color3.fromRGB(245, 245, 250),
	textDim  = Color3.fromRGB(140, 140, 160),
	success  = Color3.fromRGB(60, 200, 120),
	danger   = Color3.fromRGB(220, 70, 80),
	on       = Color3.fromRGB(50, 200, 120),
	off      = Color3.fromRGB(200, 60, 70),
}

-- ====================== SETTINGS ======================
local WHEELIE_INTERVAL = 0.025
local WHEELIE_MAX_SPEED = 130
-- Pitch = LookVector.Y  (0 = flach, höher = Vorderreifen oben)
local WHEELIE_TARGET_PITCH = 0.52   -- gewünschte Neigung (höher)
local WHEELIE_MIN_PITCH = 0.44      -- darunter: Strg-Impulse (hoch)
local WHEELIE_MAX_PITCH = 0.62      -- darüber: S-Impulse (runter)
local WHEELIE_CTRL_TAP = 0.045      -- kurze Strg-Klicks
local WHEELIE_CTRL_GAP = 0.03       -- Pause zwischen Strg-Klicks
local WHEELIE_S_TAP = 0.035         -- kurze S-Klicks
local WHEELIE_S_GAP = 0.04          -- Pause zwischen S-Klicks

local SPEED_BOOST_ON = false
local SPEED_BOOST_TARGET = 130
local SPEED_BOOST_INTERVAL = 0.05

local ACCELERATION = 8

-- ====================== STATE ======================
local worldState = {
	Trees = true, Buildings = true, Props = true,
	Police = true, Powerlines = true, Hills = true,
}
local hidden = {
	Trees = {}, Buildings = {}, Props = {},
	Police = {}, Powerlines = {}, Hills = {},
}
local policeConn = nil
local isMinimized = false
local autoWheelieOn = false
local autoWheelieThread = nil
local speedBoostThread = nil
local afkGlitchOn = false
local afkGlitchThread = nil
local character, humanoid, rootPart
local musicInput

local claimThreads = {}
local autoCollectOn = false
local autoCollectThread = nil

local keepSeatedOn = false
local manualDismount = false
local lastVehicleSeat = nil
local keepSeatThread = nil
local keepSeatGen = 0
local seatConn = nil
local stateConn = nil

-- ====================== MUSIC DISCOVERY ======================
-- Statt einer festen Liste werden alle Songs, die das Spiel aktuell kennt,
-- dynamisch aus Remotes / Modulen / Ordnern / GUI gelesen.
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

-- Nur Fallback, falls im Spiel nichts gefunden wird.
local FALLBACK_MUSIC = {
	{name = "basswav", id = 12221944},
	{name = "glassbreakwav", id = 12222005},
	{name = "HalloweenLightningwav", id = 12222019},
	{name = "HalloweenThunderwav", id = 12222030},
	{name = "hitwav", id = 12222046},
}

local ID_KEYS = {
	"id", "Id", "ID", "soundId", "SoundId", "assetId", "AssetId",
	"trackId", "TrackId", "songId", "SongId", "musicId", "MusicId",
	"value", "Value",
}
local NAME_KEYS = {
	"name", "Name", "title", "Title", "displayName", "DisplayName",
	"song", "Song", "songName", "SongName", "label", "Label", "Text", "text",
}

local SongRepo = { list = {}, seen = {} }
local CatalogRepo = { list = {}, seen = {}, cache = {} }

local CATALOG_MIN_QUERY = 2
local CATALOG_MAX_RESULTS = 240
local CATALOG_MAX_PAGES = 8
local CATALOG_RETRY_DELAY = 60

local function normalizeSongId(v)
	local n
	if type(v) == "number" then
		n = v
	elseif type(v) == "string" then
		n = tonumber(v:match("%d+"))
	end
	if n and n >= 1 and n == math.floor(n) then
		return n
	end
	return nil
end

local function insertSong(repo, name, id, meta)
	id = normalizeSongId(id)
	if not id then return nil end
	local existing = repo.seen[id]
	if existing then
		if meta and meta.artist and not existing.artist then existing.artist = meta.artist end
		if meta and meta.duration and not existing.duration then existing.duration = meta.duration end
		return existing
	end
	local nm = tostring(name or "")
	if nm == "" or nm == "nil" then nm = "Song " .. id end
	local entry = {
		name = nm,
		id = id,
		artist = meta and meta.artist or nil,
		duration = meta and meta.duration or nil,
		source = meta and meta.source or "Game",
	}
	repo.seen[id] = entry
	repo.list[#repo.list + 1] = entry
	return entry
end

local function addSong(name, id, meta)
	return insertSong(SongRepo, name, id, meta)
end

local function instanceToSong(inst)
	local id, nm
	for _, k in ipairs(ID_KEYS) do
		local v = inst:GetAttribute(k)
		if v ~= nil then
			local n = normalizeSongId(v)
			if n then id = n; break end
		end
	end
	if not id and inst:IsA("Sound") then
		id = normalizeSongId(inst.SoundId)
	end
	if not id and inst:IsA("ValueBase") then
		id = normalizeSongId(inst.Value)
	end
	if not id then
		for _, ch in ipairs(inst:GetChildren()) do
			if ch:IsA("ValueBase") and string.find(string.lower(ch.Name), "id", 1, true) then
				local n = normalizeSongId(ch.Value)
				if n then id = n; break end
			end
		end
	end
	if not id then return end
	for _, k in ipairs(NAME_KEYS) do
		local v = inst:GetAttribute(k)
		if type(v) == "string" and v ~= "" then nm = v; break end
	end
	if not nm and inst:IsA("ValueBase") and type(inst.Value) == "string" and inst.Value ~= "" and not tonumber(inst.Value) then
		nm = inst.Value
	end
	addSong(nm or inst.Name, id)
end

local function extractSongs(value, depth, visited)
	depth = depth or 0
	visited = visited or {}
	if depth > 10 then return end
	if typeof(value) == "Instance" then
		if visited[value] then return end
		visited[value] = true
		instanceToSong(value)
		for _, ch in ipairs(value:GetChildren()) do
			extractSongs(ch, depth + 1, visited)
		end
		return
	end
	if type(value) ~= "table" then return end
	if visited[value] then return end
	visited[value] = true

	local id
	for _, k in ipairs(ID_KEYS) do
		if value[k] ~= nil then
			local n = normalizeSongId(value[k])
			if n then id = n; break end
		end
	end
	if id then
		local nm
		for _, k in ipairs(NAME_KEYS) do
			if type(value[k]) == "string" and value[k] ~= "" then nm = value[k]; break end
		end
		addSong(nm, id)
	end

	if #value >= 2 then
		for i = 1, #value - 1 do
			local a, b = value[i], value[i + 1]
			if type(a) == "string" and not tonumber(a) and type(b) == "number" then
				addSong(a, b)
			end
		end
	end

	for _, v in pairs(value) do
		if type(v) == "table" or typeof(v) == "Instance" then
			extractSongs(v, depth + 1, visited)
		end
	end
end

local REMOTE_HINTS = { "song", "music", "track", "catalog", "radio", "soundtrack", "audio" }
local MODULE_HINTS = { "music", "song", "track", "catalog", "radio", "soundtrack", "audio" }
local CONTAINER_HINTS = { "music", "song", "track", "catalog", "radio", "soundtrack", "audio" }

local function nameHasHint(name, hints)
	local ln = string.lower(name)
	for _, h in ipairs(hints) do
		if string.find(ln, h, 1, true) then return true end
	end
	return false
end

local function scanRoot(root)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") then
			addSong(d.Name, d.SoundId)
		elseif d:IsA("Folder") or d:IsA("Configuration") or d:IsA("Model") or d:IsA("Frame") then
			if nameHasHint(d.Name, CONTAINER_HINTS) then
				extractSongs(d, 0, {})
			end
		end
	end
end

local function scanRemotes()
	local before = #SongRepo.list
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		for _, d in ipairs(remotes:GetDescendants()) do
			if d:IsA("RemoteFunction") and nameHasHint(d.Name, REMOTE_HINTS) then
				local ok, res = pcall(function() return d:InvokeServer() end)
				if ok and res ~= nil then
					extractSongs(res, 0, {})
				end
			end
		end
	end
	return #SongRepo.list - before
end

local function scanModules()
	local before = #SongRepo.list
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("ModuleScript") and nameHasHint(d.Name, MODULE_HINTS) then
			local ok, res = pcall(require, d)
			if ok and res ~= nil then
				extractSongs(res, 0, {})
			end
		end
	end
	return #SongRepo.list - before
end

local function rebuildSongList()
	table.clear(SongRepo.list)
	table.clear(SongRepo.seen)
	local remoteN, moduleN = 0, 0
	pcall(function() remoteN = scanRemotes() end)
	pcall(function() moduleN = scanModules() end)
	pcall(function() scanRoot(ReplicatedStorage) end)
	pcall(function() scanRoot(playerGui) end)
	if #SongRepo.list == 0 then
		for _, e in ipairs(FALLBACK_MUSIC) do
			addSong(e.name, e.id)
		end
	end
	return #SongRepo.list, remoteN, moduleN
end

-- Prüft, ob eine Audio-ID wirklich abspielbar ist (nur funktionierende Songs).
local function isSongPlayable(id)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = 0
	s.Parent = SoundService
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ s })
	end)
	local working = ok and s.IsLoaded and s.TimeLength > 0
	s:Destroy()
	return working
end

-- ====================== ROBLOX AUDIO CATALOG ======================
-- Sucht on-demand im kompletten öffentlichen Roblox-Creator-Store (Musik).
local catalogState = { loading = false, query = "", generation = 0 }

local function getCatalogCache(keyword)
	local c = CatalogRepo.cache[keyword]
	if not c then return nil end
	if #c.ids > 0 or (os.clock() - c.time) < CATALOG_RETRY_DELAY then
		return c
	end
	return nil
end

local function fetchCatalogSongs(keyword)
	local cached = getCatalogCache(keyword)
	if cached then return #cached.ids end

	local pages, lastErr
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			local params = Instance.new("AudioSearchParams")
			params.SearchKeyword = keyword
			pcall(function() params.AudioSubType = Enum.AudioSubType.Music end)
			return AssetService:SearchAudioAsync(params)
		end)
		if ok and res then
			pages = res
			break
		end
		lastErr = res
		if attempt < 3 then task.wait(0.5 * attempt) end
	end
	if not pages then
		CatalogRepo.cache[keyword] = { ids = {}, time = os.clock() }
		return nil, tostring(lastErr)
	end

	local ids = {}
	for _ = 1, CATALOG_MAX_PAGES do
		local items = pages:GetCurrentPage()
		for _, audio in ipairs(items) do
			local id = normalizeSongId(audio.Id or audio.AssetId)
			if id then
				local title = tostring(audio.Title or audio.Name or ("Song " .. id))
				local artist = audio.Artist and tostring(audio.Artist) or nil
				local display = title
				if artist and artist ~= "" then display = title .. " — " .. artist end
				insertSong(CatalogRepo, display, id, {
					artist = artist,
					duration = audio.Duration,
					source = "Roblox",
				})
				ids[#ids + 1] = id
				if #ids >= CATALOG_MAX_RESULTS then break end
			end
		end
		if #ids >= CATALOG_MAX_RESULTS or pages.IsFinished then break end
		local okAdvance = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not okAdvance then break end
	end

	CatalogRepo.cache[keyword] = { ids = ids, time = os.clock() }
	return #ids
end


-- ====================== HELPERS ======================
local function getCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	return character
end

local function safeGet(path)
	local cur = game
	for _, n in ipairs(string.split(path, ".")) do
		cur = cur:FindFirstChild(n)
		if not cur then return nil end
	end
	return cur
end

local function findPart(container)
	if not container then return nil end
	if container:IsA("BasePart") then return container end
	if container:IsA("Model") and container.PrimaryPart then return container.PrimaryPart end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function getVehicleRoot()
	if not humanoid then return nil end
	local seat = humanoid.SeatPart
	if not seat then return nil end
	if not (seat:IsA("VehicleSeat") or seat:IsA("Seat")) then return nil end
	return seat.AssemblyRootPart or seat
end

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function scooterDisplayName(fullName)
	local n = fullName
	if n:sub(1, 7):lower() == "scooter" then
		n = n:sub(8)
	end
	return n ~= "" and n or fullName
end

local function applySpeed(root, targetSpeed)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.1 then
		flatLook = flatLook.Unit
	else
		flatLook = Vector3.new(0, 0, -1)
	end
	local vel = root.AssemblyLinearVelocity
	local current = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local newSpeed
	if current < targetSpeed then
		newSpeed = math.min(targetSpeed, current + ACCELERATION)
	else
		newSpeed = targetSpeed
	end
	local newFlat = flatLook * newSpeed
	root.AssemblyLinearVelocity = Vector3.new(newFlat.X, vel.Y, newFlat.Z)
end

-- ====================== AUTO WHEELIE ======================
-- Kurze, schnelle Strg/S-Impulse → setzt sich stabil auf Zielwinkel.
-- Keine Physik-Manipulation → Lenkung (A/D) bleibt normal.
local wheelieCtrlDown = false
local wheelieSDown = false
local wheelieKeyUntil = 0
local wheelieNextTap = 0

local function wheelieSetKey(key, down)
	pcall(function()
		VirtualInputManager:SendKeyEvent(down, key, false, game)
	end)
end

local function wheelieReleaseAll()
	if wheelieCtrlDown then
		wheelieSetKey(Enum.KeyCode.LeftControl, false)
		wheelieCtrlDown = false
	end
	if wheelieSDown then
		wheelieSetKey(Enum.KeyCode.S, false)
		wheelieSDown = false
	end
	wheelieKeyUntil = 0
	wheelieNextTap = 0
end

local function startAutoWheelie()
	getCharacter()
	wheelieReleaseAll()
	autoWheelieThread = task.spawn(function()
		while autoWheelieOn do
			if humanoid and humanoid.Health > 0 then
				local root = getVehicleRoot()
				if root then
					local vel = root.AssemblyLinearVelocity
					local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
					local pitch = root.CFrame.LookVector.Y
					local now = os.clock()

					-- Laufenden Tastendruck beenden wenn Zeit abgelaufen
					if wheelieCtrlDown and now >= wheelieKeyUntil then
						wheelieSetKey(Enum.KeyCode.LeftControl, false)
						wheelieCtrlDown = false
						wheelieNextTap = now + WHEELIE_CTRL_GAP
					end
					if wheelieSDown and now >= wheelieKeyUntil then
						wheelieSetKey(Enum.KeyCode.S, false)
						wheelieSDown = false
						wheelieNextTap = now + WHEELIE_S_GAP
					end

					if flatSpeed > 4 then
						if pitch > WHEELIE_MAX_PITCH then
							-- Zu steil → kurze S-Impulse
							if wheelieCtrlDown then
								wheelieSetKey(Enum.KeyCode.LeftControl, false)
								wheelieCtrlDown = false
							end
							if not wheelieSDown and not wheelieCtrlDown and now >= wheelieNextTap then
								wheelieSetKey(Enum.KeyCode.S, true)
								wheelieSDown = true
								wheelieKeyUntil = now + WHEELIE_S_TAP
							end
						elseif pitch < WHEELIE_MIN_PITCH then
							-- Zu flach → kurze Strg-Impulse (höhere Frequenz wenn weit weg)
							if wheelieSDown then
								wheelieSetKey(Enum.KeyCode.S, false)
								wheelieSDown = false
							end
							local gap = WHEELIE_CTRL_GAP
							if pitch < WHEELIE_TARGET_PITCH - 0.2 then
								gap = 0.015 -- schneller hoch wenn noch sehr flach
							end
							if not wheelieCtrlDown and not wheelieSDown and now >= wheelieNextTap then
								wheelieSetKey(Enum.KeyCode.LeftControl, true)
								wheelieCtrlDown = true
								wheelieKeyUntil = now + WHEELIE_CTRL_TAP
								wheelieNextTap = now + WHEELIE_CTRL_TAP + gap
							end
						else
							-- Im stabilen Fenster um TARGET → nichts drücken
							if wheelieCtrlDown then
								wheelieSetKey(Enum.KeyCode.LeftControl, false)
								wheelieCtrlDown = false
							end
							if wheelieSDown then
								wheelieSetKey(Enum.KeyCode.S, false)
								wheelieSDown = false
							end
						end
						applySpeed(root, WHEELIE_MAX_SPEED)
					else
						wheelieReleaseAll()
					end
				else
					wheelieReleaseAll()
				end
			else
				wheelieReleaseAll()
			end
			task.wait(WHEELIE_INTERVAL)
		end
		wheelieReleaseAll()
	end)
end

local function stopAutoWheelie()
	autoWheelieOn = false
	wheelieReleaseAll()
	autoWheelieThread = nil
end

-- ====================== SPEED BOOST (+ Touch Button) ======================
local SPEED_TOUCH_HELD = false
local speedTouchGui = nil
local speedTouchBtn = nil
local speedTouchConnBegan = nil
local speedTouchConnEnded = nil
local speedTouchConnLeave = nil

local function destroySpeedTouchUI()
	SPEED_TOUCH_HELD = false
	if speedTouchConnBegan then pcall(function() speedTouchConnBegan:Disconnect() end); speedTouchConnBegan = nil end
	if speedTouchConnEnded then pcall(function() speedTouchConnEnded:Disconnect() end); speedTouchConnEnded = nil end
	if speedTouchConnLeave then pcall(function() speedTouchConnLeave:Disconnect() end); speedTouchConnLeave = nil end
	if speedTouchGui then
		pcall(function() speedTouchGui:Destroy() end)
		speedTouchGui = nil
		speedTouchBtn = nil
	end
end

local function createSpeedTouchUI()
	destroySpeedTouchUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KukiSpeedTouch"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	speedTouchGui = gui

	local btn = Instance.new("TextButton")
	btn.Name = "AccelBtn"
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -18, 1, -28)
	btn.Size = UDim2.fromOffset(96, 96)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = "SPEED"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(245, 245, 250)
	btn.AutoButtonColor = false
	btn.Parent = gui
	speedTouchBtn = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 80, 255)
	stroke.Thickness = 2.5
	stroke.Parent = btn

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.Position = UDim2.new(0, 0, 1, -22)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = Color3.fromRGB(180, 180, 200)
	hint.Text = "halten"
	hint.Parent = btn

	local function setHeld(on)
		SPEED_TOUCH_HELD = on
		if not btn or not btn.Parent then return end
		if on then
			btn.BackgroundColor3 = Color3.fromRGB(50, 200, 120)
			btn.Text = "GO"
			stroke.Color = Color3.fromRGB(50, 200, 120)
		else
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			btn.Text = "SPEED"
			stroke.Color = Color3.fromRGB(120, 80, 255)
		end
	end

	speedTouchConnBegan = btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(true)
		end
	end)
	speedTouchConnEnded = btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(false)
		end
	end)
	speedTouchConnLeave = btn.MouseButton1Up:Connect(function()
		setHeld(false)
	end)
end

local function startSpeedBoost()
	getCharacter()
	-- Touch-Button auf Handy / Touch-Geräten
	if IS_MOBILE or UserInputService.TouchEnabled then
		createSpeedTouchUI()
	end
	speedBoostThread = task.spawn(function()
		while SPEED_BOOST_ON do
			if humanoid and humanoid.Health > 0 then
				local root = getVehicleRoot()
				if root then
					local shouldBoost = false
					if IS_MOBILE or UserInputService.TouchEnabled then
						-- Handy: nur solange Touch-Button gehalten wird
						shouldBoost = SPEED_TOUCH_HELD
					else
						-- PC: W-Taste
						shouldBoost = UserInputService:IsKeyDown(Enum.KeyCode.W)
					end
					if shouldBoost then
						applySpeed(root, SPEED_BOOST_TARGET)
					end
				end
			end
			task.wait(SPEED_BOOST_INTERVAL)
		end
	end)
end

local function stopSpeedBoost()
	SPEED_BOOST_ON = false
	speedBoostThread = nil
	destroySpeedTouchUI()
end

-- ====================== AFK GLITCH / AUTO FARM ======================
local function startAfkGlitch()
	afkGlitchThread = task.spawn(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, game)

		while afkGlitchOn do
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, game)
			task.wait(0.5)
		end

		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
	end)
end

local function stopAfkGlitch()
	afkGlitchOn = false
	pcall(function()
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
	end)
	afkGlitchThread = nil
end

-- ====================== AUTO FARM WHEELIE (STATIONARY) ======================
-- Hält das Fahrzeug dauerhaft im Wheelie, ohne sich vom Fleck zu bewegen.
local FARM_WHEELIE_PITCH = math.rad(32)
local farmWheelieOn = false
local farmWheelieThread = nil
local farmWheelieRoot = nil
local farmWheelieBasePos = nil

local function startFarmWheelie()
	getCharacter()
	farmWheelieRoot = nil
	farmWheelieBasePos = nil
	farmWheelieThread = task.spawn(function()
		while farmWheelieOn do
			if humanoid and humanoid.Health > 0 then
				local root = getVehicleRoot()
				if root then
					if farmWheelieRoot ~= root then
						farmWheelieRoot = root
						farmWheelieBasePos = root.Position
					end
					local look = root.CFrame.LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					if flat.Magnitude > 0.05 then
						flat = flat.Unit
					else
						flat = Vector3.new(0, 0, -1)
					end
					local basePos = farmWheelieBasePos or root.Position
					local yaw = CFrame.lookAt(basePos, basePos + flat, Vector3.yAxis)
					root.CFrame = yaw * CFrame.Angles(FARM_WHEELIE_PITCH, 0, 0)
					pcall(function()
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
					end)
				else
					farmWheelieRoot = nil
					farmWheelieBasePos = nil
				end
			end
			task.wait()
		end
	end)
end

local function stopFarmWheelie()
	farmWheelieOn = false
	farmWheelieThread = nil
	farmWheelieRoot = nil
	farmWheelieBasePos = nil
end

-- ====================== AUTO CLAIM ======================
local function getClaimRemote()
	return safeGet("ReplicatedStorage.Remotes.Achievements.ClaimAchievement")
end

local function startAutoClaim(achName, flagName)
	if claimThreads[achName] then return end
	claimThreads[achName] = task.spawn(function()
		while _G[flagName] do
			local remote = getClaimRemote()
			if remote then
				pcall(function()
					if remote:IsA("RemoteEvent") then
						remote:FireServer(achName)
					elseif remote:IsA("RemoteFunction") then
						remote:InvokeServer(achName)
					end
				end)
			end
			task.wait(1.5)
		end
		claimThreads[achName] = nil
	end)
end

-- ====================== AUTO COLLECT QUESTS ======================
local function startAutoCollect()
	autoCollectThread = task.spawn(function()
		local questIds = {1, 2, 3}
		local index = 1
		while autoCollectOn do
			local remote = safeGet("ReplicatedStorage.Remotes.Quests.ClaimQuest")
			if remote then
				local id = questIds[index]
				pcall(function()
					if remote:IsA("RemoteEvent") then
						remote:FireServer(id)
					elseif remote:IsA("RemoteFunction") then
						remote:InvokeServer(id)
					end
				end)
			end
			index = index + 1
			if index > #questIds then
				index = 1
			end
			task.wait(1.2)
		end
	end)
end

local function stopAutoCollect()
	autoCollectOn = false
	autoCollectThread = nil
end

-- ====================== WORLD ======================
local folderPaths = {
	Trees      = { "Workspace.Map.Trees", "Workspace.Map.Fields.FieldTrees" },
	Buildings  = { "Workspace.Buildings" },
	Props      = { "Workspace.Map.Props", "Workspace.Map.Lights" },
	Police     = { "Workspace.PoliceNPCs" },
	Powerlines = { "Workspace.Map.Powerlines" },
	Hills      = { "Workspace.Map.Hills" },
}

local function setVisible(key, visible)
	local paths = folderPaths[key]
	if not paths then return end
	if not visible then
		for _, path in ipairs(paths) do
			local folder = safeGet(path)
			if folder then
				for _, child in ipairs(folder:GetChildren()) do
					hidden[key][child] = child.Parent
					child.Parent = nil
				end
			end
		end
		if key == "Police" then
			local pf = safeGet("Workspace.PoliceNPCs")
			if pf then
				if policeConn then policeConn:Disconnect() end
				policeConn = pf.ChildAdded:Connect(function(child)
					task.wait()
					if not worldState.Police then
						hidden.Police[child] = pf
						child.Parent = nil
					end
				end)
			end
		end
	else
		if key == "Police" and policeConn then
			policeConn:Disconnect()
			policeConn = nil
		end
		for inst, parent in pairs(hidden[key]) do
			if inst and parent then pcall(function() inst.Parent = parent end) end
		end
		table.clear(hidden[key])
	end
end

-- ====================== TELEPORT ======================
local function teleportTo(target)
	getCharacter()
	if not rootPart then return end
	local part = findPart(target)
	if part then rootPart.CFrame = part.CFrame + Vector3.new(0, 5, 0) end
end

local function teleportToMyRide()
	local rides = workspace:FindFirstChild("Rides")
	if not rides then return end
	local ride = rides:FindFirstChild("Ride_" .. player.Name)
	if ride then teleportTo(ride) end
end

local function teleportToPumpkin()
	getCharacter()
	if not rootPart then return end
	local folder = workspace:FindFirstChild("HalloweenPumpkins")
	if not folder then return end
	local children = folder:GetChildren()
	if #children == 0 then return end
	local best, bestDist = nil, math.huge
	for _, child in ipairs(children) do
		local part = findPart(child)
		if part then
			local d = (part.Position - rootPart.Position).Magnitude
			if d < bestDist then bestDist, best = d, child end
		end
	end
	teleportTo(best or children[1])
end

-- ====================== TOP SPEED / SPAWN ======================
local function findTopSpeed()
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local v = stats:FindFirstChild("Top Speed")
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v end
	end
	local v = player:FindFirstChild("Top Speed")
	if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v end
	for _, d in ipairs(player:GetDescendants()) do
		if d.Name == "Top Speed" and (d:IsA("IntValue") or d:IsA("NumberValue")) then return d end
	end
	return nil
end

local function spawnScooter(fullName)
	local remote = safeGet("ReplicatedStorage.Remotes.Rides.SpawnRide")
	if not remote then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local rides = remotes and remotes:FindFirstChild("Rides")
		remote = rides and rides:FindFirstChild("SpawnRide")
	end
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(fullName)
	elseif remote and remote:IsA("RemoteFunction") then
		task.spawn(function() pcall(function() remote:InvokeServer(fullName) end) end)
	end
end

local function buyScooter(fullName)
	local remote = safeGet("ReplicatedStorage.Remotes.Rides.BuyRide")
	if not remote then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local rides = remotes and remotes:FindFirstChild("Rides")
		remote = rides and rides:FindFirstChild("BuyRide")
	end
	if remote and remote:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return remote:InvokeServer(fullName)
		end)
		if ok then return result == true end
	elseif remote and remote:IsA("RemoteEvent") then
		remote:FireServer(fullName)
		return nil
	end
	return false
end

-- ====================== UI HELPERS (SPLASH) ======================
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COL.border
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ====================== LIBRARY ======================
local LIB_URL = "https://raw.githubusercontent.com/xqrto/RobloxCheats/refs/heads/main/lib.lua"

local function loadLibrary()
	local ok, lib = pcall(function()
		if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("Lib.lua") then
			return loadstring(readfile("Lib.lua"))()
		end
	end)
	if ok and lib then return lib end
	local ok2, lib2 = pcall(function()
		return loadstring(game:HttpGet(LIB_URL))()
	end)
	if ok2 and lib2 then return lib2 end
	error("[Kuki] Lib.lua konnte nicht geladen werden: " .. tostring(lib2))
end

local Lib = loadLibrary()

-- Altes Fenster / alte Threads sauber entfernen (beim Re-Execute)
if _G.KukiCleanup then
	pcall(_G.KukiCleanup)
	_G.KukiCleanup = nil
end
if _G.KukiWindow then
	pcall(function() _G.KukiWindow:Destroy() end)
	_G.KukiWindow = nil
end

local windowClosed = false
local cleanup

-- ====================== STAY ON VEHICLE ======================
local KEEP_SEAT_INTERVAL = 0.12
local KEEP_SEAT_TELEPORT_DIST = 18
local KEEP_SEAT_RETRY_DELAY = 0.25
local lastSeatForce = 0
local RAGDOLL_STATES = {
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Physics,
}

local function isSeatPart(part)
	return part ~= nil and (part:IsA("VehicleSeat") or part:IsA("Seat"))
end

local function setRagdollStatesEnabled(hum, enabled)
	if not hum or hum.Health <= 0 then return end
	for _, state in ipairs(RAGDOLL_STATES) do
		pcall(function() hum:SetStateEnabled(state, enabled) end)
	end
end

local function isRagdolled(hum)
	if not hum then return false end
	for _, name in ipairs({ "Ragdoll", "Ragdolled", "IsRagdoll", "isRagdoll" }) do
		if hum:GetAttribute(name) == true then return true end
	end
	local ch = hum.Parent
	if ch then
		for _, name in ipairs({ "Ragdoll", "Ragdolled", "IsRagdoll", "isRagdoll" }) do
			if ch:GetAttribute(name) == true then return true end
		end
	end
	local state = hum:GetState()
	return state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Physics
end

local function forceSeat(hum, seat, noCooldown)
	if not hum or not seat or not seat.Parent or hum.Health <= 0 then return false end
	if hum.SeatPart == seat then return true end
	local now = os.clock()
	if not noCooldown and now - lastSeatForce < 0.1 then return false end
	lastSeatForce = now

	pcall(function()
		if hum.PlatformStand then hum.PlatformStand = false end
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	pcall(function() seat:Sit(hum) end)
	pcall(function()
		hum.Sit = true
		hum:ChangeState(Enum.HumanoidStateType.Seated)
	end)
	return hum.SeatPart == seat
end

local function bindSeatTracking()
	local ch = player.Character
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	character = ch
	humanoid = hum
	rootPart = hum.RootPart

	if seatConn then seatConn:Disconnect(); seatConn = nil end
	if stateConn then stateConn:Disconnect(); stateConn = nil end

	seatConn = hum.Seated:Connect(function(active, seat)
		if active and isSeatPart(seat) then
			lastVehicleSeat = seat
			manualDismount = false
			if keepSeatedOn then
				setRagdollStatesEnabled(hum, false)
				forceSeat(hum, seat)
			end
		end
	end)

	if keepSeatedOn then
		setRagdollStatesEnabled(hum, false)
		stateConn = hum.StateChanged:Connect(function(_, newState)
			if not keepSeatedOn or manualDismount then return end
			if newState == Enum.HumanoidStateType.Ragdoll
				or newState == Enum.HumanoidStateType.FallingDown
				or newState == Enum.HumanoidStateType.Physics then
				setRagdollStatesEnabled(hum, false)
				local seat = lastVehicleSeat
				if seat and seat.Parent then
					forceSeat(hum, seat)
				end
			end
		end)
	end

	if isSeatPart(hum.SeatPart) then
		lastVehicleSeat = hum.SeatPart
	end
end

local function startStayOnVehicle()
	keepSeatGen += 1
	local gen = keepSeatGen
	keepSeatThread = task.spawn(function()
		local nextAttempt = 0
		while keepSeatedOn and not windowClosed and keepSeatGen == gen do
			local hum = humanoid
			if not hum or hum.Parent ~= player.Character then
				bindSeatTracking()
				hum = humanoid
			end
			if hum and hum.Health > 0 and not manualDismount then
				local seat = lastVehicleSeat
				if seat and seat.Parent then
					if hum.SeatPart ~= seat and os.clock() >= nextAttempt then
						local root = hum.RootPart
						local far = root and (root.Position - seat.Position).Magnitude > KEEP_SEAT_TELEPORT_DIST
						if far then
							pcall(function()
								root.CFrame = seat.CFrame * CFrame.new(0, 2.5, 0)
							end)
						end
						if isRagdolled(hum) then
							setRagdollStatesEnabled(hum, false)
						end
						forceSeat(hum, seat)
						nextAttempt = os.clock() + KEEP_SEAT_RETRY_DELAY
					elseif hum.SeatPart == seat and hum.PlatformStand then
						pcall(function() hum.PlatformStand = false end)
					end
				end
			end
			task.wait(KEEP_SEAT_INTERVAL)
		end
		if keepSeatGen == gen then
			keepSeatThread = nil
		end
	end)
end

local function stopStayOnVehicle()
	keepSeatedOn = false
	keepSeatGen += 1
	keepSeatThread = nil
	if stateConn then stateConn:Disconnect(); stateConn = nil end
	if humanoid and humanoid.Health > 0 then
		setRagdollStatesEnabled(humanoid, true)
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Space then return end
	if not keepSeatedOn then return end
	if UserInputService:GetFocusedTextBox() then return end
	if humanoid and isSeatPart(humanoid.SeatPart) then
		manualDismount = true
		setRagdollStatesEnabled(humanoid, true)
		pcall(function() humanoid.Sit = false end)
		pcall(function() humanoid.Jump = true end)
	end
end)

-- ====================== WINDOW ======================
local guiSize = UDim2.fromOffset(480, 620)
if IS_MOBILE then
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(390, 700)
	local w = math.clamp(math.floor(vp.X * 0.94), 280, 420)
	local h = math.clamp(math.floor(vp.Y * 0.72), 380, 560)
	guiSize = UDim2.fromOffset(w, h)
end

local Window = Lib:CreateWindow({
	Name = "KukirinLiveGui",
	Title = "Kuki Life",
	Logo = "rbxassetid://131769820484042",
	Size = guiSize,
	Accent = COL.accent,
	Theme = {
		bg = COL.bg,
		panel = COL.surface,
		panelHi = COL.surface2,
		line = COL.border,
		text = COL.text,
		textDim = COL.textDim,
		accent = COL.accent,
		accentDim = Color3.fromRGB(70, 45, 150),
	},
	ToggleKey = Enum.KeyCode.RightShift,
	OnClose = function()
		if cleanup then cleanup() end
	end,
})
_G.KukiWindow = Window

local function ctrlInst(control)
	if typeof(control) == "Instance" then return control end
	if control and control.Instance then return control.Instance end
	return nil
end

local function setLabelColor(label, color)
	local inst = label and label.Instance
	if not inst then return end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		inst.TextColor3 = color
	else
		local text = inst:FindFirstChildWhichIsA("TextLabel")
		if text then text.TextColor3 = color end
	end
end

-- ====================== TAB WORLD ======================
do
local worldTab = Window:Tab("World")

local visSec = worldTab:Section("Visibility")

local function addWorldToggle(text, key)
	visSec:Toggle({
		Text = text,
		Default = false,
		Callback = function(on)
			worldState[key] = not on
			setVisible(key, worldState[key])
		end,
	})
end

addWorldToggle("No Trees", "Trees")
addWorldToggle("No Buildings", "Buildings")
addWorldToggle("No Props + Lights", "Props")
addWorldToggle("No Powerlines", "Powerlines")
addWorldToggle("No Hills", "Hills")

local policeSec = worldTab:Section("Police")
policeSec:Toggle({
	Text = "No Police",
	Default = false,
	Callback = function(on)
		worldState.Police = not on
		setVisible("Police", worldState.Police)
	end,
})

local quickTpSec = worldTab:Section("Quick TP")
quickTpSec:Button({ Text = "TP to My Ride", Callback = teleportToMyRide })
quickTpSec:Button({ Text = "Pumpkin TP", Callback = teleportToPumpkin })

-- Buy 2x Money / Rideout host
local buyMoneySec = worldTab:Section("Buy 2x Money")
local hostPriceLabel = buyMoneySec:Label({ Text = "Price: Loading...", Color = COL.textDim })
local function readHostPrice()
    local hostObj = safeGet("Players." .. player.Name .. ".PlayerGui.MainUi.HostRideoutFrame.Frame.CanvasGroup.Host")
    if not hostObj then return nil end
    if hostObj:IsA("TextLabel") or hostObj:IsA("TextButton") or hostObj:IsA("TextBox") then
        return hostObj.Text
    elseif hostObj:IsA("ValueBase") then
        return tostring(hostObj.Value)
    end
    return nil
end
local function updateHostPrice()
    local price = readHostPrice()
    hostPriceLabel:SetText("Price: " .. tostring(price or "N/A"))
end
updateHostPrice()
task.spawn(function()
    while not windowClosed do
        updateHostPrice()
        task.wait(1)
    end
end)
buyMoneySec:Button({
    Text = "Buy 2x Money",
    Callback = function()
        local remote = safeGet("ReplicatedStorage.Remotes.Rideout.Host")
        if not remote or not remote:IsA("RemoteFunction") then
            pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Buy 2x Money", Text = "Host RemoteFunction not found", Duration = 4}) end)
            return
        end
        task.spawn(function()
            local ok, success, message = pcall(function()
                return remote:InvokeServer()
            end)
            local title, body
            if not ok then
                title, body = "Buy 2x Money - Error", tostring(success)
            elseif success == true then
                title, body = "Buy 2x Money", "Success!"
            else
                title, body = "Buy 2x Money", tostring(message or "Could not host rideout")
            end
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = body, Duration = 5})
            end)
        end)
    end,
})
end

-- ====================== TAB TPs ======================
do
local tpTab = Window:Tab("TPs")

local rideoutSec = tpTab:Section("Rideouts")
local rideoutFolder = safeGet("Workspace.Rideout")
if rideoutFolder then
	local rideouts = rideoutFolder:GetChildren()
	table.sort(rideouts, function(a, b) return a.Name < b.Name end)
	if #rideouts == 0 then
		rideoutSec:Label({ Text = "(No Rideouts)", Color = COL.textDim })
	else
		for _, child in ipairs(rideouts) do
			local target = child
			rideoutSec:Button({
				Text = target.Name,
				Callback = function() teleportTo(target) end,
			})
		end
	end
else
	rideoutSec:Label({ Text = "(Workspace.Rideout not found)", Color = COL.danger })
end

local poiSec = tpTab:Section("POIs")
local poisFolder = safeGet("Workspace.POIs")
if poisFolder then
	local pois = poisFolder:GetChildren()
	table.sort(pois, function(a, b) return a.Name < b.Name end)
	if #pois == 0 then
		poiSec:Label({ Text = "(No POIs)", Color = COL.textDim })
	else
		for _, child in ipairs(pois) do
			local target = child
			poiSec:Button({
				Text = target.Name,
				Callback = function() teleportTo(target) end,
			})
		end
	end
else
	poiSec:Label({ Text = "(Workspace.POIs not found)", Color = COL.danger })
end
end

-- ====================== TAB FUN ======================
local speedConn
do
local funTab = Window:Tab("Fun")

local topSpeedSec = funTab:Section("Top Speed")
local speedDisplay = topSpeedSec:Label({ Text = "Looking for Top Speed...", Color = COL.success })
local speedValue = nil
speedConn = nil
local speedInput = topSpeedSec:Input({
	Text = "New Value",
	Placeholder = "New value...",
	Default = "",
})

topSpeedSec:Button({
	Text = "Change Value",
	Callback = function()
		if not speedValue then
			speedDisplay:SetText("Top Speed not found")
			setLabelColor(speedDisplay, COL.danger)
			return
		end
		local n = tonumber(speedInput:Get())
		if n and n >= 0 and n <= 1e9 and n == math.floor(n) then
			speedValue.Value = n
			speedInput:Set("", true)
		else
			speedDisplay:SetText("Invalid number!")
			setLabelColor(speedDisplay, COL.danger)
			task.delay(1.5, function()
				if not windowClosed and speedValue then
					speedDisplay:SetText("Current: " .. tostring(speedValue.Value))
					setLabelColor(speedDisplay, COL.success)
				end
			end)
		end
	end,
})

task.spawn(function()
	for _ = 1, 20 do
		speedValue = findTopSpeed()
		if speedValue then break end
		task.wait(0.5)
	end
	if speedValue then
		local function upd()
			if windowClosed then return end
			speedDisplay:SetText("Current: " .. tostring(speedValue.Value))
			setLabelColor(speedDisplay, COL.success)
		end
		upd()
		speedConn = speedValue:GetPropertyChangedSignal("Value"):Connect(upd)
	else
		speedDisplay:SetText("Top Speed not found")
		setLabelColor(speedDisplay, COL.danger)
	end
end)

-- ===== Music =====
local function sendMusic(id)
	local numId = tonumber(id)
	if not numId then return end

	local remote = safeGet("ReplicatedStorage.Remotes.Rides.SetMusic")
	if not remote then
		local r = ReplicatedStorage:FindFirstChild("Remotes")
		local rides = r and r:FindFirstChild("Rides")
		remote = rides and rides:FindFirstChild("SetMusic")
	end

	if not remote then
		warn("[Music] SetMusic Remote nicht gefunden")
		return
	end

	local ok, err
	if remote:IsA("RemoteEvent") then
		ok, err = pcall(function() remote:FireServer(numId) end)
	elseif remote:IsA("RemoteFunction") then
		ok, err = pcall(function() remote:InvokeServer(numId) end)
	else
		ok, err = false, "Unsupported remote type"
	end

	if not ok then
		warn("[Music] " .. tostring(err))
	end
end

local musicSec = funTab:Section("Scooter Music")

local musicIdInput = musicSec:Input({
	Text = "Music ID",
	Placeholder = "Music ID (Zahl)",
	Default = "",
})

local scanning = false
local validating = false
local lastQuery = ""
local MAX_MUSIC_RESULTS = 40

local resultsSec = funTab:Section("Results")
local resultsStatus = resultsSec:Label({ Text = "Song suchen, um Ergebnisse zu sehen.", Color = COL.textDim })
local resultButtons = {}

local function clearResults()
	for _, inst in ipairs(resultButtons) do
		if inst and inst.Parent then inst:Destroy() end
	end
	table.clear(resultButtons)
end

local renderMusicResults

local function requestCatalog(q)
	if #q < CATALOG_MIN_QUERY or q:match("^%d+$") then return end
	if catalogState.loading and catalogState.query == q then return end
	if getCatalogCache(q) then return end

	catalogState.query = q
	catalogState.loading = true
	catalogState.error = nil
	catalogState.generation += 1
	local gen = catalogState.generation

	task.spawn(function()
		local count, err = fetchCatalogSongs(q)
		if gen ~= catalogState.generation then return end
		catalogState.loading = false
		catalogState.query = ""
		if count == nil then
			catalogState.error = err
			warn("[Music] Katalogsuche fehlgeschlagen: " .. tostring(err))
		end
		if lastQuery == q then renderMusicResults() end
	end)
end

renderMusicResults = function()
	if windowClosed then return end
	clearResults()
	local q = lastQuery
	if q == "" then
		resultsStatus:SetText("Song suchen, um Ergebnisse zu sehen.")
		setLabelColor(resultsStatus, COL.textDim)
		return
	end

	local matches, seenIds = {}, {}
	local function push(entry)
		if #matches >= MAX_MUSIC_RESULTS then return end
		if seenIds[entry.id] then return end
		seenIds[entry.id] = true
		matches[#matches + 1] = entry
	end

	for _, entry in ipairs(SongRepo.list) do
		if string.find(string.lower(entry.name), q, 1, true)
			or (entry.artist and string.find(string.lower(entry.artist), q, 1, true))
			or tostring(entry.id) == q then
			push(entry)
			if #matches >= MAX_MUSIC_RESULTS then break end
		end
	end
	if #matches < MAX_MUSIC_RESULTS then
		for _, entry in ipairs(CatalogRepo.list) do
			if string.find(string.lower(entry.name), q, 1, true)
				or tostring(entry.id) == q then
				push(entry)
				if #matches >= MAX_MUSIC_RESULTS then break end
			end
		end
	end

	if #matches == 0 then
		local num = q:match("^%d+$")
		if num then
			local inst = ctrlInst(resultsSec:Button({
				Text = "ID " .. num .. " senden",
				Callback = function() sendMusic(num) end,
			}))
			if inst then resultButtons[#resultButtons + 1] = inst end
			resultsStatus:SetText("Kein Song gefunden – ID direkt senden.")
		else
			resultsStatus:SetText("Keine Treffer.")
		end
		setLabelColor(resultsStatus, COL.textDim)
		return
	end

	resultsStatus:SetText(#matches .. " Treffer")
	setLabelColor(resultsStatus, COL.success)
	for _, entry in ipairs(matches) do
		local item = entry
		local label = item.name
		if item.artist and item.artist ~= "" then
			label = label .. " — " .. item.artist
		end
		local inst = ctrlInst(resultsSec:Button({
			Text = label,
			Callback = function()
				musicIdInput:Set(tostring(item.id), true)
				sendMusic(item.id)
			end,
		}))
		if inst then resultButtons[#resultButtons + 1] = inst end
	end
end

local function doMusicSearch(text)
	local q = string.lower((text or ""):gsub("^%s*(.-)%s*$", "%1"))
	lastQuery = q
	renderMusicResults()
	if #q >= CATALOG_MIN_QUERY and not q:match("^%d+$") and not getCatalogCache(q) then
		requestCatalog(q)
	end
end

local searchInput = musicSec:Input({
	Text = "Song suchen",
	Placeholder = "Song suchen...",
	Default = "",
	Callback = function(text, enterPressed)
		if enterPressed then doMusicSearch(text) end
	end,
})

pcall(function()
	local inst = searchInput.Instance
	if inst and inst:IsA("TextBox") then
		local token = 0
		inst:GetPropertyChangedSignal("Text"):Connect(function()
			token = token + 1
			local myToken = token
			task.delay(0.35, function()
				if windowClosed or myToken ~= token then return end
				doMusicSearch(inst.Text)
			end)
		end)
	end
end)

musicSec:Button({
	Text = "Search",
	Callback = function()
		doMusicSearch(searchInput:Get())
	end,
})

musicSec:Button({
	Text = "Confirm / Senden",
	Callback = function()
		local id = tostring(musicIdInput:Get()):match("%d+")
		if id then sendMusic(id) end
	end,
})

musicSec:Button({
	Text = "Songs neu laden",
	Callback = function()
		if scanning then return end
		scanning = true
		task.spawn(function()
			local n, remoteN, moduleN = rebuildSongList()
			print("[Music] " .. n .. " Songs gefunden (remote=" .. remoteN .. ", module=" .. moduleN .. ")")
			if lastQuery ~= "" then renderMusicResults() end
			scanning = false
		end)
	end,
})

musicSec:Button({
	Text = "Nur funktionierende prüfen",
	Callback = function()
		if validating then return end
		validating = true
		task.spawn(function()
			local total = #SongRepo.list
			if total == 0 then
				validating = false
				return
			end
			local working = {}
			for i, entry in ipairs(SongRepo.list) do
				if isSongPlayable(entry.id) then
					working[#working + 1] = entry
				end
				if i % 10 == 0 then
					task.wait()
				end
			end
			table.clear(SongRepo.list)
			table.clear(SongRepo.seen)
			for _, e in ipairs(working) do
				SongRepo.seen[e.id] = e
				SongRepo.list[#SongRepo.list + 1] = e
			end
			if lastQuery ~= "" then renderMusicResults() end
			validating = false
		end)
	end,
})

task.spawn(function()
	local n, remoteN, moduleN = rebuildSongList()
	print("[Music] " .. n .. " Songs geladen (remote=" .. remoteN .. ", module=" .. moduleN .. ")")
end)
end

-- ====================== TAB SCOOTERS ======================
do
local scooterTab = Window:Tab("Scooters")
local scooterSec = scooterTab:Section("Scooters")

local scooterStatus = scooterSec:Label({ Text = "Loading scooters...", Color = COL.textDim })

local function showStatus(text, color, duration)
	scooterStatus:SetText(text)
	setLabelColor(scooterStatus, color or COL.textDim)
	if duration then
		task.delay(duration, function()
			if scooterStatus and scooterStatus.Instance and scooterStatus.Instance.Parent then
				scooterStatus:SetText("Click a scooter to spawn or buy")
				setLabelColor(scooterStatus, COL.textDim)
			end
		end)
	end
end

task.spawn(function()
	local getRidesRemote = safeGet("ReplicatedStorage.Remotes.Rides.GetRides")
	local ridesList = nil

	if getRidesRemote and getRidesRemote:IsA("RemoteFunction") then
		local ok, result = pcall(function() return getRidesRemote:InvokeServer() end)
		if ok and typeof(result) == "table" then
			ridesList = result
		end
	end

	if windowClosed then return end

	if ridesList then
		local items = {}
		for _, entry in pairs(ridesList) do
			if typeof(entry) == "table" and entry.Name then
				table.insert(items, entry)
			end
		end
		table.sort(items, function(a, b)
			return (a.DisplayName or a.Name) < (b.DisplayName or b.Name)
		end)

		if #items == 0 then
			scooterSec:Label({ Text = "(No scooters found)", Color = COL.textDim })
			showStatus("Could not load scooter list", COL.danger)
		else
			showStatus("Click a scooter to spawn or buy", COL.textDim)
			for _, entry in ipairs(items) do
				local fullName = entry.Name
				local display = entry.DisplayName or scooterDisplayName(fullName)
				local isOwned = entry.Owned == true
				local buttonText = isOwned and display or (display .. "  [BUY]")
				scooterSec:Button({
					Text = buttonText,
					Callback = function()
						if isOwned then
							spawnScooter(fullName)
							showStatus("Spawned: " .. display, COL.success, 2.5)
						else
							showStatus("Buying " .. display .. "...", COL.textDim)
							task.spawn(function()
								local success = buyScooter(fullName)
								if success == true then
									showStatus("Purchased: " .. display .. "!", COL.success, 3)
								else
									showStatus("Not enough money or different acquisition method", COL.danger, 3.5)
								end
							end)
						end
					end,
				})
			end
		end
		return
	end

	local scooterFolder = ReplicatedStorage:FindFirstChild("Scooters")
		or ReplicatedStorage:FindFirstChild("Scootersa")
	if scooterFolder then
		local items = scooterFolder:GetChildren()
		table.sort(items, function(a, b) return a.Name < b.Name end)
		if #items == 0 then
			scooterSec:Label({ Text = "(Folder empty)", Color = COL.textDim })
		else
			showStatus("Click to spawn (fallback mode)", COL.textDim)
			for _, item in ipairs(items) do
				local fullName = item.Name
				local display = scooterDisplayName(fullName)
				scooterSec:Button({
					Text = display,
					Callback = function()
						spawnScooter(fullName)
						showStatus("Spawned: " .. display, COL.success, 2)
					end,
				})
			end
		end
	else
		scooterSec:Label({ Text = "GetRides remote / Scooters folder missing", Color = COL.danger })
		showStatus("Could not load scooter list", COL.danger)
	end
end)
end

-- ====================== TAB AUTO ======================
do
local autoTab = Window:Tab("Auto")

-- Auto Instant Delivery: move the vehicle assembly (not just the character) so the
-- player stays with the vehicle and does not get left behind by vehicle physics.
local deliverySec = autoTab:Section("Auto Instant Delivery")
local autoDeliveryOn = false
local autoDeliveryThread = nil
local deliveryRunActive = false

local function deliveryNotify(message, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Auto Instant Delivery",
			Text = tostring(message),
			Duration = duration or 4,
		})
	end)
end

local function teleportVehicleTo(target)
	local part = findPart(target)
	if not part then return false end
	getCharacter()

	-- Get off the scooter first: tap Space, release it, and allow the character
	-- to detach before moving only the character. The scooter itself is left put.
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	end)
	task.wait(0.08)
	pcall(function()
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
	if humanoid then
		pcall(function() humanoid.Sit = false end)
		pcall(function() humanoid.Jump = true end)
	end
	task.wait(0.3)
	getCharacter()
	if not rootPart then return false end

	-- Teleport the player after dismounting; do not CFrame-move the scooter.
	local destination = part.CFrame + Vector3.new(0, 5, 0)
	return pcall(function()
		rootPart.CFrame = destination
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function activateDeliveryPrompt(customer)
	if not customer then return false end
	for _, item in ipairs(customer:GetDescendants()) do
		if item:IsA("ProximityPrompt") and item.Enabled then
			local fired = false
			if type(fireproximityprompt) == "function" then
				fired = pcall(function() fireproximityprompt(item) end)
			end
			if not fired then
				fired = pcall(function()
					item:InputHoldBegin()
					task.wait(math.max(item.HoldDuration, 0.1))
					item:InputHoldEnd()
				end)
			end
			return fired
		end
	end
	return false
end

local function startAutoInstantDelivery()
	if autoDeliveryThread then return end
	autoDeliveryThread = task.spawn(function()
		while (autoDeliveryOn or deliveryRunActive) and not windowClosed do
			if not deliveryRunActive then
				local testNpc = safeGet("Workspace.NPCs.Test")
				local startRemote = safeGet("ReplicatedStorage.Remotes.FoodDelivery.Start")
				if not testNpc then
					deliveryNotify("Workspace.NPCs.Test was not found", 4)
					task.wait(2)
				elseif not startRemote or not startRemote:IsA("RemoteFunction") then
					deliveryNotify("FoodDelivery.Start RemoteFunction was not found", 4)
					task.wait(2)
				else
					if not teleportVehicleTo(testNpc) then
						deliveryNotify("Could not teleport to the test NPC", 4)
						task.wait(2)
					else
						task.wait(0.35)
						local invokeOk, started = pcall(function() return startRemote:InvokeServer() end)
						if invokeOk and started == true then
							deliveryRunActive = true
							local customer = safeGet("Workspace.DeliveryCustomer")
							local customerWaitStarted = os.clock()
							while not customer and os.clock() - customerWaitStarted < 10 and not windowClosed do
								task.wait(0.2)
								customer = safeGet("Workspace.DeliveryCustomer")
							end
							if customer and teleportVehicleTo(customer) then
								task.wait(0.5)
								while deliveryRunActive and not windowClosed do
									customer = safeGet("Workspace.DeliveryCustomer")
									if not customer then break end
									activateDeliveryPrompt(customer)
									task.wait(0.25)
								end
								-- Finish the active run even if the toggle was switched off.
								deliveryRunActive = false
								if not autoDeliveryOn then
									deliveryNotify("Current run finished. Auto Instant Delivery is off.", 5)
								end
							else
								deliveryRunActive = false
								deliveryNotify("DeliveryCustomer was not found or could not be reached", 4)
								task.wait(1)
							end
						elseif not invokeOk then
							deliveryNotify("Could not start delivery", 4)
							task.wait(2)
						else
							-- A false return means no run started; retry while enabled.
							task.wait(2)
						end
					end
				end
			end
			task.wait(0.1)
		end
		autoDeliveryThread = nil
	end)
end

deliverySec:Toggle({
	Text = "Auto Instant Delivery",
	Default = false,
	Callback = function(on)
		autoDeliveryOn = on
		if on then
			startAutoInstantDelivery()
		else
			if deliveryRunActive then
				deliveryNotify("Finishing current run...", 4)
			else
				deliveryNotify("Auto Instant Delivery is off", 3)
			end
		end
	end,
})

local claimSec = autoTab:Section("Auto Claim Achievements")

claimSec:Toggle({
	Text = "Auto Claim Wheelie Time",
	Default = false,
	Callback = function(on)
		_G.autoClaimWheelie = on
		if on then startAutoClaim("WheelieTime", "autoClaimWheelie") end
	end,
})
claimSec:Toggle({
	Text = "Auto Claim Going Fast",
	Default = false,
	Callback = function(on)
		_G.autoClaimTopSpeed = on
		if on then startAutoClaim("TopSpeed", "autoClaimTopSpeed") end
	end,
})
claimSec:Toggle({
	Text = "Auto Claim Playtime",
	Default = false,
	Callback = function(on)
		_G.autoClaimPlaytime = on
		if on then startAutoClaim("Playtime", "autoClaimPlaytime") end
	end,
})

local questSec = autoTab:Section("Quests")
questSec:Toggle({
	Text = "Auto Collect Quests",
	Default = false,
	Callback = function(on)
		if on then
			autoCollectOn = true
			startAutoCollect()
		else
			stopAutoCollect()
		end
	end,
})
questSec:Button({
	Text = "Take New Quest",
	Callback = function()
		local remote = safeGet("ReplicatedStorage.Events.Halloween.Remotes.TakeQuests")
		if remote then
			pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer()
				elseif remote:IsA("RemoteFunction") then
					remote:InvokeServer()
				end
			end)
		end
	end,
})

local caseSec = autoTab:Section("Auto Open Case")

local CASE_VALUES = {
	["Halloween Crate"] = "Halloween",
	["Charms Crate"] = "Charms",
	["Basic Crate"] = "Street",
}
local CASE_OPTIONS = { "Halloween Crate", "Charms Crate", "Basic Crate" }
local autoCaseOn = false
local autoCaseThread = nil
local autoCaseChoice = CASE_OPTIONS[1]

local function startAutoCase()
	if autoCaseThread then return end
	autoCaseThread = task.spawn(function()
		while autoCaseOn and not windowClosed do
			local remote = safeGet("ReplicatedStorage.Remotes.Cases.OpenCase")
			if remote then
				local arg = CASE_VALUES[autoCaseChoice] or autoCaseChoice
				pcall(function()
					if remote:IsA("RemoteEvent") then
						remote:FireServer(arg)
					elseif remote:IsA("RemoteFunction") then
						local result1, result2, result3 = remote:InvokeServer(arg)
						-- Support both a three-value return and a single table return.
						if typeof(result1) == "table" then
							local result = result1
							result1, result2, result3 = result[1], result[2], result[3]
						end
						if result1 == true then
							showCaseWin(result2 or "Unknown item", result3 or "?")
						end
					end
				end)
			end
			task.wait(1)
		end
		autoCaseThread = nil
	end)
end

caseSec:Toggle({
	Text = "Auto Open Case",
	Default = false,
	Callback = function(on)
		autoCaseOn = on
		if on then startAutoCase() end
	end,
})

caseSec:Dropdown({
	Text = "Case",
	Options = CASE_OPTIONS,
	Default = autoCaseChoice,
	Callback = function(value)
		autoCaseChoice = value
	end,
})
end

-- ====================== TAB VEHICLE ======================
local vehicleTab = Window:Tab("Vehicle")

-- Live speedometer text from MainUi.Speedometer.Background.kmh
local speedometerSec = vehicleTab:Section("Speedometer")
local kmhLabel = speedometerSec:Label({ Text = "KM/H: Loading...", Color = COL.success })
local function readKmhText()
    local kmhObj = safeGet("Players." .. player.Name .. ".PlayerGui.MainUi.Speedometer.Background.kmh")
    if not kmhObj then return nil end
    if kmhObj:IsA("TextLabel") or kmhObj:IsA("TextButton") or kmhObj:IsA("TextBox") then
        return kmhObj.Text
    elseif kmhObj:IsA("ValueBase") then
        return tostring(kmhObj.Value)
    end
    return nil
end
local function updateKmhLabel()
    kmhLabel:SetText("KM/H: " .. tostring(readKmhText() or "N/A"))
end
updateKmhLabel()
task.spawn(function()
    while not windowClosed do
        updateKmhLabel()
        task.wait(0.2)
    end
end)

local eventSec = vehicleTab:Section("Auto Event")
local autoEventButton = eventSec:Button({
	Text = "Open Auto Event",
	Callback = function()
		task.spawn(function()
			local ok, err = pcall(function()
				local src = game:HttpGet("https://raw.githubusercontent.com/xqrto/RobloxCheats/refs/heads/main/key/keysys.lua")
				local fn = loadstring(src)
				if fn then fn() end
			end)
			if not ok then
				warn("[Auto Event] " .. tostring(err))
			end
		end)
	end,
})
local autoEventButtonInst = ctrlInst(autoEventButton)
if autoEventButtonInst then
	local glow = Instance.new("UIStroke")
	glow.Name = "AutoEventGlow"
	glow.Color = COL.accent2
	glow.Thickness = 1.5
	glow.Transparency = 0.2
	glow.Parent = autoEventButtonInst
	local pulse = TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.65,
		Thickness = 2.5
	})
	pulse:Play()
end
eventSec:Button({
	Text = "Close Key System",
	Callback = function()
		local keyGui = playerGui:FindFirstChild("PumpkinTP")
		if keyGui then
			keyGui:Destroy()
		end
	end,
})
eventSec:Label({ Text = "Levels the complete Halloween event automatically (key system)", Color = COL.textDim, TextSize = 12 })
eventSec:Label({ Text = "made by mxrzelino", Color = COL.accent2, TextSize = 12 })

local autoMoneyOn = false
local startAutoMoney

local autoMoneySec = vehicleTab:Section("Auto Money")
autoMoneySec:Toggle({
	Text = "Auto Money",
	Default = false,
	Callback = function(on)
		autoMoneyOn = on
		if on then startAutoMoney() end
	end,
})

-- ====================== AUTO MONEY ======================
-- Adapted from the supplied low-lag version; only the Auto Money toggle is exposed.

local function getMoneyRoot()
	getCharacter()
	if not humanoid or humanoid.Health <= 0 then return nil end
	return rootPart
end

local function getMoneyTarget()
	local root = getMoneyRoot()
	if not root or not humanoid then return root, false end
	local seat = humanoid.SeatPart
	if seat then
		local model = seat:FindFirstAncestorOfClass("Model")
		if model then
			if not model.PrimaryPart then model.PrimaryPart = seat end
			return model, true
		end
	end
	return root, false
end

local function autoMoneyWaitUntilYStable()
	local root = getMoneyRoot()
	if not root then return end
	local lastY = root.Position.Y
	local stableCount, timeout = 0, 0
	while autoMoneyOn and timeout < 100 do
		task.wait(0.08)
		root = getMoneyRoot()
		if not root then return end
		local currentY = root.Position.Y
		if math.abs(currentY - lastY) < 0.05 then
			stableCount += 1
			if stableCount >= 4 then return end
		else
			stableCount = 0
		end
		lastY = currentY
		timeout += 1
	end
end

local function autoMoneyFloat()
	local root = getMoneyRoot()
	if not root then return end
	local targetY = root.Position.Y + math.random(16, 26) / 10
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(0, 1e6, 0)
	bv.Velocity = Vector3.new(0, 42, 0)
	bv.Parent = root
	local started = tick()
	while tick() - started < 1.4 do
		root = getMoneyRoot()
		if not root or not autoMoneyOn then break end
		if root.Position.Y >= targetY then break end
		task.wait()
	end
	if bv and bv.Parent then bv:Destroy() end
end

local function autoMoneySpin()
	local target, isVehicle = getMoneyTarget()
	if not target then return end
	local holdPos
	if isVehicle then
		if not target.PrimaryPart then return end
		holdPos = target.PrimaryPart.Position
	else
		holdPos = target.Position
	end
	local totalDegrees, degreesPerFrame, rotated = 2880, 33, 0
	local root = getMoneyRoot()
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	while rotated < totalDegrees and autoMoneyOn do
		target, isVehicle = getMoneyTarget()
		if not target then break end
		local step = math.min(degreesPerFrame, totalDegrees - rotated)
		rotated += step
		local currentPos = isVehicle and target.PrimaryPart and target.PrimaryPart.Position or target.Position
		if not currentPos then break end
		local newPos = Vector3.new(holdPos.X, currentPos.Y + 0.065, holdPos.Z)
		local newCFrame = CFrame.new(newPos) * CFrame.Angles(0, math.rad(rotated), 0)
		local ok = pcall(function()
			if isVehicle then
				if not target.PrimaryPart then target.PrimaryPart = humanoid.SeatPart end
				target:SetPrimaryPartCFrame(newCFrame)
			else
				target.CFrame = newCFrame
			end
		end)
		if not ok then break end
		root = getMoneyRoot()
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		task.wait()
	end
end

local function autoMoneyPushDownSlightly()
	local root = getMoneyRoot()
	if not root then return end
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(0, 1e5, 0)
	bv.Velocity = Vector3.new(0, -18, 0)
	bv.Parent = root
	task.wait(0.1)
	if bv and bv.Parent then bv:Destroy() end
end

startAutoMoney = function()
	task.spawn(function()
		while autoMoneyOn and not windowClosed do
			local root = getMoneyRoot()
			if not root then
				task.wait(0.4)
				continue
			end
			autoMoneyFloat()
			if not autoMoneyOn then break end
			autoMoneySpin()
			if not autoMoneyOn then break end
			autoMoneyPushDownSlightly()
			if not autoMoneyOn then break end
			autoMoneyWaitUntilYStable()
			if not autoMoneyOn then break end
			task.wait(0.35)
		end
	end)
end

local farmSec = vehicleTab:Section("Farm")
farmSec:Toggle({
	Text = "Auto Farm",
	Default = false,
	Callback = function(on)
		if on then
			afkGlitchOn = true
			startAfkGlitch()
		else
			stopAfkGlitch()
		end
	end,
})
farmSec:Toggle({
	Text = "Auto Farm Wheelie (Stationary)",
	Default = false,
	Callback = function(on)
		if on then
			stopAutoWheelie()
			stopSpeedBoost()
			farmWheelieOn = true
			startFarmWheelie()
		else
			stopFarmWheelie()
		end
	end,
})
farmSec:Slider({
	Text = "Farm Wheelie Angle",
	Min = 1,
	Max = 85,
	Default = math.floor(math.deg(FARM_WHEELIE_PITCH)),
	Suffix = "°",
	Callback = function(n)
		FARM_WHEELIE_PITCH = math.rad(math.clamp(n, 1, 85))
	end,
})

local staySec = vehicleTab:Section("Stay On Vehicle")
staySec:Toggle({
	Text = "Stay on Vehicle (Anti-Ragdoll)",
	Default = false,
	Callback = function(on)
		if on then
			keepSeatedOn = true
			manualDismount = false
			bindSeatTracking()
			startStayOnVehicle()
		else
			stopStayOnVehicle()
		end
	end,
})
staySec:Label({ Text = "Not Working.", Color = COL.textDim })

local wheelieSec = vehicleTab:Section("Auto Wheelie")
wheelieSec:Toggle({
	Text = "Auto Wheelie",
	Default = false,
	Callback = function(on)
		if on then
			autoWheelieOn = true
			startAutoWheelie()
		else
			stopAutoWheelie()
		end
	end,
})
wheelieSec:Slider({
	Text = "Wheelie Max Speed",
	Min = 0,
	Max = 500,
	Default = WHEELIE_MAX_SPEED,
	Callback = function(n) WHEELIE_MAX_SPEED = n end,
})

local scooterSpeedSec = vehicleTab:Section("Scooter Speed")
scooterSpeedSec:Toggle({
	Text = "Speed",
	Default = false,
	Callback = function(on)
		if on then
			SPEED_BOOST_ON = true
			startSpeedBoost()
		else
			stopSpeedBoost()
		end
	end,
})
scooterSpeedSec:Slider({
	Text = "Scooter Speed",
	Min = 0,
	Max = 500,
	Default = SPEED_BOOST_TARGET,
	Callback = function(n) SPEED_BOOST_TARGET = n end,
})
scooterSpeedSec:Slider({
	Text = "Acceleration",
	Min = 0,
	Max = 50,
	Default = ACCELERATION,
	Callback = function(n) ACCELERATION = n end,
})

-- ====================== TAB ITEMS ======================
do
local itemsTab = Window:Tab("Items")
local itemsSec = itemsTab:Section("Owned Items")

local itemsStatus = itemsSec:Label({ Text = "Loading owned items...", Color = COL.textDim })
local itemInstances = {}
local loadItems

itemsSec:Button({
	Text = "Refresh Items",
	Callback = function()
		loadItems()
	end,
})

local function clearItems()
	for _, inst in ipairs(itemInstances) do
		if inst and inst.Parent then inst:Destroy() end
	end
	table.clear(itemInstances)
end

local function addItemLabel(text, color, size)
	local lbl = itemsSec:Label({ Text = text, Color = color or COL.text, TextSize = size or 13 })
	local inst = ctrlInst(lbl)
	if inst then itemInstances[#itemInstances + 1] = inst end
	return lbl
end

loadItems = function()
	if windowClosed then return end
	clearItems()
	itemsStatus:SetText("Loading owned items...")
	setLabelColor(itemsStatus, COL.textDim)

	task.spawn(function()
		local remote = safeGet("ReplicatedStorage.Remotes.Inventory.GetOwnedItems")
			or safeGet("ReplicatedStorage.Remotes.GetOwnedItems")
			or safeGet("ReplicatedStorage.Remotes.Player.GetItems")

		local data = nil
		if remote and remote:IsA("RemoteFunction") then
			local ok, result = pcall(function() return remote:InvokeServer() end)
			if ok then data = result end
		end

		if not data then
			data = {
				"Charm:Cheezburger", "Charm:Hippo", "Charm:Pizza", "Charm:Taco", "Charm:Tripmine", "Charm:Watermelon",
				"Decal:Lightning", "Decal:None", "Decal:Red", "Decal:Stock", "Decal:Street Race", "Decal:Lava", "Decal:Sakura", "Decal:Galaxy",
				"ForkFlip:ForkFlip",
				"Hardware:25A Controller", "Hardware:48V Battery", "Hardware:52V Battery", "Hardware:Accessory Removal", "Hardware:Sport Windings",
				"Nameplate:Nameplate 1", "Nameplate:Nameplate 2",
				"Removal:ScreenRemoval", "Removal:WheelCoverRemoval",
				"Scooter:ScooterG2", "Scooter:ScooterG2Max", "Scooter:ScooterG2Ultra", "Scooter:ScooterG3",
				"Sticker:Lighting", "Sticker:Ghost", "Sticker:Rocket", "Sticker:Skull",
				"TireEffect:Ash", "TireEffect:Toxic", "TireEffect:Gold", "TireEffect:Sparkles",
				"WheelieBar:Wheelie Bar",
				"CrashGuard:Crash Guards",
				"Charm:Gravity Coil", "Charm:Verity"
			}
		end

		if windowClosed then return end
		clearItems()

		if not data or type(data) ~= "table" then
			itemsStatus:SetText("Failed to load items")
			setLabelColor(itemsStatus, COL.danger)
			return
		end

		itemsStatus:SetText("Your owned items")
		setLabelColor(itemsStatus, COL.success)

		local categories = {}
		for _, entry in ipairs(data) do
			if type(entry) == "string" then
				local cat, name = string.match(entry, "([^:]+):(.+)")
				if cat and name then
					categories[cat] = categories[cat] or {}
					table.insert(categories[cat], name)
				end
			end
		end

		local order = {"Scooter", "Charm", "Decal", "Sticker", "TireEffect", "Hardware", "Nameplate", "WheelieBar", "ForkFlip", "Removal", "CrashGuard"}

		for _, cat in ipairs(order) do
			local list = categories[cat]
			if list and #list > 0 then
				table.sort(list)
				addItemLabel(cat:upper(), COL.accent2, 12)
				for _, itemName in ipairs(list) do
					addItemLabel("  " .. itemName, COL.text, 12)
				end
			end
		end
	end)
end

task.spawn(loadItems)
end

-- ====================== TAB OTHER ======================
do
local otherTab = Window:Tab("Other")
local otherSec = otherTab:Section("Players")

local otherStatus = otherSec:Label({ Text = "Loading players...", Color = COL.textDim })
local otherInstances = {}

otherSec:Button({
	Text = "Refresh Player List",
	Callback = function()
		-- loadOther wird weiter unten definiert; Button-Callback läuft erst nach dem Skriptstart.
		if _G.KukiLoadOther then _G.KukiLoadOther() end
	end,
})

local function clearOther()
	for _, inst in ipairs(otherInstances) do
		if inst and inst.Parent then inst:Destroy() end
	end
	table.clear(otherInstances)
end

local function addOtherLabel(text, color, size)
	local lbl = otherSec:Label({ Text = text, Color = color or COL.text, TextSize = size or 12 })
	local inst = ctrlInst(lbl)
	if inst then otherInstances[#otherInstances + 1] = inst end
	return lbl
end

local function getPlayerScooterFrame(plr)
	local rides = workspace:FindFirstChild("Rides")
	if not rides then return nil end

	local ride = rides:FindFirstChild("Ride_" .. plr.Name)
	if not ride then return nil end

	local body = ride:FindFirstChild("Body")
	if body then
		for _, child in ipairs(body:GetChildren()) do
			if child.Name:find("Frame") then
				return child.Name:gsub("Frame", "")
			end
		end
	end

	for _, desc in ipairs(ride:GetDescendants()) do
		if desc.Name:find("Frame") and (desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Folder")) then
			return desc.Name:gsub("Frame", "")
		end
	end
	return nil
end

local function getPlayerThumb(userId)
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size48x48
		)
	end)
	if ok and content then return content end
	return "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

local function addPlayerRow(plr, frameName)
	-- Row container parented into the tab content via a Label placeholder then rebuilt
	local content = otherTab.Content
	if not content then return end

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 52)
	row.BackgroundColor3 = COL.surface
	row.BorderSizePixel = 0
	row.LayoutOrder = otherTab.NextOrder or 0
	if otherTab.NextOrder then
		otherTab.NextOrder = otherTab.NextOrder + 1
	end
	row.Parent = content
	otherInstances[#otherInstances + 1] = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = COL.border
	stroke.Thickness = 1
	stroke.Transparency = 0.55
	stroke.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.new(0, 40, 0, 40)
	avatar.Position = UDim2.new(0, 8, 0.5, -20)
	avatar.BackgroundColor3 = COL.surface2
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = row
	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(0, 8)
	avCorner.Parent = avatar

	task.spawn(function()
		avatar.Image = getPlayerThumb(plr.UserId)
	end)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -60, 0, 22)
	nameLbl.Position = UDim2.new(0, 56, 0, 6)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
	nameLbl.Font = Enum.Font.GothamMedium
	nameLbl.TextSize = 13
	nameLbl.TextColor3 = COL.text
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Parent = row

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -60, 0, 18)
	subLbl.Position = UDim2.new(0, 56, 0, 28)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = frameName and ("Frame: " .. frameName) or "No scooter"
	subLbl.Font = Enum.Font.Gotham
	subLbl.TextSize = 11
	subLbl.TextColor3 = frameName and COL.accent2 or COL.textDim
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.TextTruncate = Enum.TextTruncate.AtEnd
	subLbl.Parent = row
end

local function loadOther()
	if windowClosed then return end
	clearOther()
	otherStatus:SetText("Loading players...")
	setLabelColor(otherStatus, COL.textDim)

	task.spawn(function()
		if windowClosed then return end
		clearOther()
		local players = Players:GetPlayers()

		table.sort(players, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)

		otherStatus:SetText(#players .. " Players online")
		setLabelColor(otherStatus, COL.success)

		for _, plr in ipairs(players) do
			local frameName = getPlayerScooterFrame(plr)
			addPlayerRow(plr, frameName)
		end
	end)
end

_G.KukiLoadOther = loadOther
task.spawn(loadOther)
end

-- ====================== TAB MAP ======================
-- Index: https://raw.githubusercontent.com/xqrto/RobloxCheats/refs/heads/main/KukiMaps/index.lua
--   return { "WinterLand.lua", ... }
-- Externe Maps: loadstring → return { Load=fn, Unload=fn }
-- Alles in MapSys (eine Local), damit kein "Out of local registers".

local MapSys = {
	loaded = false,
	building = false,
	activeName = nil,
	external = nil,
	savedCF = nil,
	folder = nil,
	wheelConn = nil,
	raeder = {},
	lightingBackup = nil,
	status = nil,
	origin = Vector3.new(6000, 500, 6000),
	lichtAnpassen = true,
	baseUrl = "https://raw.githubusercontent.com/xqrto/RobloxCheats/refs/heads/main/KukiMaps/",
	indexUrl = "https://raw.githubusercontent.com/xqrto/RobloxCheats/refs/heads/main/KukiMaps/index.lua",
	registry = { { name = "Race City", builtin = true } },
}
MapSys.spawnCF = CFrame.lookAt(
	MapSys.origin + Vector3.new(0, 3.4, -560),
	MapSys.origin + Vector3.new(0, 3.4, -559)
)

MapSys.fetchIndex = function()
	local list = { { name = "Race City", builtin = true } }
	local src
	local ok = pcall(function() src = game:HttpGet(MapSys.indexUrl) end)
	if not ok or type(src) ~= "string" or #src < 5 then
		warn("[Map] index.lua konnte nicht geladen werden")
		MapSys.registry = list
		return list
	end
	local fn, err = loadstring(src)
	if not fn then
		warn("[Map] index.lua loadstring: " .. tostring(err))
		MapSys.registry = list
		return list
	end
	local ok2, data = pcall(fn)
	if not ok2 or type(data) ~= "table" then
		warn("[Map] index.lua ungültig: " .. tostring(data))
		MapSys.registry = list
		return list
	end
	for _, item in ipairs(data) do
		if type(item) == "string" and item ~= "" then
			local file = item
			if not string.find(file, "%.lua$") then
				file = file .. ".lua"
			end
			local name = file:gsub("%.lua$", "")
			list[#list + 1] = {
				name = name,
				url = MapSys.baseUrl .. file,
			}
		end
	end
	MapSys.registry = list
	return list
end

MapSys.teleportTo = function(cf)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		local modell = hum.SeatPart:FindFirstAncestorOfClass("Model")
		if modell and modell ~= char then
			pcall(function() modell:PivotTo(cf + Vector3.new(0, 2, 0)) end)
			return
		end
	end
	pcall(function() char:PivotTo(cf) end)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

MapSys.savePosition = function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		local modell = hum.SeatPart:FindFirstAncestorOfClass("Model")
		if modell and modell ~= char then
			MapSys.savedCF = modell:GetPivot()
			return
		end
	end
	MapSys.savedCF = char:GetPivot()
end

MapSys.setStatus = function(text, color)
	if MapSys.status and not windowClosed then
		pcall(function()
			MapSys.status:SetText(text)
			setLabelColor(MapSys.status, color or COL.textDim)
		end)
	end
end

MapSys.unloadBuiltin = function()
	if MapSys.wheelConn then
		MapSys.wheelConn:Disconnect()
		MapSys.wheelConn = nil
	end
	MapSys.raeder = {}
	if MapSys.folder then
		pcall(function() MapSys.folder:Destroy() end)
		MapSys.folder = nil
	end
	local alt = workspace:FindFirstChild("LokaleMap")
	if alt then pcall(function() alt:Destroy() end) end
	if MapSys.lightingBackup then
		pcall(function()
			Lighting.ClockTime = MapSys.lightingBackup.ClockTime
			Lighting.Brightness = MapSys.lightingBackup.Brightness
			Lighting.OutdoorAmbient = MapSys.lightingBackup.OutdoorAmbient
		end)
		for _, n in ipairs({ "LokaleMapAtmosphere", "LokaleMapBloom" }) do
			local e = Lighting:FindFirstChild(n)
			if e then e:Destroy() end
		end
		MapSys.lightingBackup = nil
	end
end

MapSys.unload = function()
	if MapSys.external then
		pcall(function()
			local u = MapSys.external.Unload or MapSys.external.unload
			if type(u) == "function" then u() end
		end)
		MapSys.external = nil
	end
	MapSys.unloadBuiltin()
	if MapSys.savedCF then
		MapSys.teleportTo(MapSys.savedCF)
		MapSys.savedCF = nil
	end
	MapSys.loaded = false
	MapSys.building = false
	MapSys.activeName = nil
	MapSys.setStatus("Map entfernt – zurück teleportiert.", COL.textDim)
	print("[Map] entladen")
end

-- cleanup-Hook (eine Local-Zuweisung)
local unloadLokaleMap = MapSys.unload

MapSys.loadExternal = function(entry)
	local url = entry.url
	if type(url) ~= "string" or url == "" or not string.find(url, "^https?://") then
		error("Ungültige URL für '" .. tostring(entry.name) .. "'")
	end
	local src
	assert(pcall(function() src = game:HttpGet(url) end) and type(src) == "string" and #src > 10,
		"HttpGet fehlgeschlagen")
	local fn, loadErr = loadstring(src)
	assert(fn, "loadstring: " .. tostring(loadErr))
	local okRun, mod = pcall(fn)
	assert(okRun, "Script-Fehler: " .. tostring(mod))
	assert(type(mod) == "table", "Map muss return { Load, Unload }")
	local loadFn = mod.Load or mod.load
	assert(type(loadFn) == "function", "Map braucht Load = function()")
	MapSys.external = mod
	loadFn()
end

MapSys.activate = function(entry)
	if MapSys.building then
		MapSys.setStatus("Noch am Laden – bitte warten...", COL.danger)
		return
	end
	-- gleiche Map nochmal = nur entladen
	if MapSys.loaded and MapSys.activeName == entry.name then
		MapSys.unload()
		return
	end
	MapSys.building = true
	task.spawn(function()
		-- Aktive Map zuerst sauber entladen + zurück-TP abwarten
		if MapSys.loaded then
			local prev = MapSys.activeName or "?"
			MapSys.setStatus("Entlade " .. prev .. " ...", COL.textDim)
			print("[Map] wechsle: " .. prev .. " → " .. entry.name)
			MapSys.unload()
			MapSys.building = true -- unload setzt building=false; Wechsel läuft weiter
			task.wait(0.45)
			-- kurz warten bis Character/Fahrzeug wieder steht
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					for _ = 1, 6 do
						if hrp.AssemblyLinearVelocity.Magnitude < 8 then break end
						task.wait(0.08)
					end
				end
			end
			task.wait(0.15)
		end

		MapSys.setStatus("Lade " .. entry.name .. " ...", COL.textDim)
		print("[Map] lade: " .. entry.name)
		MapSys.savePosition()

		local ok, err = pcall(function()
			if entry.builtin then
				MapSys.buildRaceCity()
				MapSys.teleportTo(MapSys.spawnCF)
			else
				MapSys.loadExternal(entry)
			end
		end)
		if not ok then
			warn("[Map] Fehler bei '" .. entry.name .. "': " .. tostring(err))
			MapSys.setStatus("Fehler: " .. tostring(err), COL.danger)
			MapSys.building = false
			MapSys.loaded = false
			MapSys.activeName = nil
			MapSys.external = nil
			return
		end
		MapSys.loaded = true
		MapSys.building = false
		MapSys.activeName = entry.name
		MapSys.setStatus(entry.name .. " aktiv · nochmal klicken = zurück", COL.success)
		print("[Map] aktiv: " .. entry.name)
	end)
end

pcall(function()
	local mapTab = Window:Tab("Map")
	local mapSec = mapTab:Section("Maps")
	MapSys.status = mapSec:Label({
		Text = "Maps werden geladen...",
		Color = COL.textDim,
	})
	task.spawn(function()
		local list = MapSys.fetchIndex()
		if windowClosed then return end
		MapSys.setStatus("Keine Map aktiv. Klick = laden, nochmal = entladen + zurück.", COL.textDim)
		for _, entry in ipairs(list) do
			local e = entry
			mapSec:Button({
				Text = e.name,
				Callback = function() MapSys.activate(e) end,
			})
		end
		print("[Map] " .. (#list) .. " Maps aus Index")
	end)
end)

-- Race City Builder (eigene Function = eigener Register-Pool)
MapSys.buildRaceCity = function()
	local MAP_ORIGIN = MapSys.origin
	local LICHT_ANPASSEN = MapSys.lichtAnpassen
	-- Race City (eingebaut) – komplette Map, ohne T-Taste und ohne Auto-Teleport
	local STRASSEN_BREITE = 36
	local STRASSE_OBEN = 0.4
	local BORDSTEIN_OBEN = 0.9
	local RAMPEN_TIEFE = 5
	local LINIEN = { -600, -300, 0, 300, 600 }
	local BLOCK = 264
	local HB = BLOCK / 2
	local ARENA = 282
	local STRASSEN_HALB = 618
	local BASIS = BORDSTEIN_OBEN
	local rnd = Random.new(1337)

	local alt = workspace:FindFirstChild("LokaleMap")
	if alt then alt:Destroy() end

	local map = Instance.new("Folder")
	map.Name = "LokaleMap"
	map.Parent = workspace
	MapSys.folder = map

	local function ordner(name, parent)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent or map
		return f
	end

	local fBoden = ordner("Boden")
	local fStrassen = ordner("Strassen")
	local fMarkierung = ordner("Markierungen")
	local fRampen = ordner("UnsichtbareRampen")
	local fArena = ordner("Arena")
	local fBerge = ordner("Berge")

	local zaehler = 0

	local function box(parent, name, size, rel, color, material, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(MAP_ORIGIN + rel)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if collide == false then
			p.CanCollide = false
			p.CanQuery = false
		end
		p.Parent = parent
		zaehler += 1
		if zaehler % 500 == 0 then task.wait() end
		return p
	end

	local function zylinder(parent, name, hoehe, durchmesser, rel, color, material, collide)
		local p = box(parent, name, Vector3.new(hoehe, durchmesser, durchmesser), rel, color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.new(MAP_ORIGIN + rel) * CFrame.Angles(0, 0, math.rad(90))
		return p
	end

	local function kugel(parent, name, durchmesser, rel, color, material, collide)
		local p = box(parent, name, Vector3.new(durchmesser, durchmesser, durchmesser), rel, color, material, collide)
		p.Shape = Enum.PartType.Ball
		return p
	end

	local function balken(parent, p1, p2, dicke, color, material, collide)
		local a, b = MAP_ORIGIN + p1, MAP_ORIGIN + p2
		local p = box(parent, "Balken", Vector3.new(dicke, dicke, (b - a).Magnitude), (p1 + p2) / 2, color, material, collide)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		return p
	end

	local function schraege(parent, laenge, hoehe, tiefe, basisY, kante, richtung, dicke, farbe, material)
		local up = Vector3.new(0, 1, 0)
		local s = (richtung * tiefe + up * hoehe).Unit
		local n = (up * tiefe - richtung * hoehe).Unit
		local mitte = kante - richtung * (tiefe / 2) + Vector3.new(0, basisY + hoehe / 2, 0)
		local pos = MAP_ORIGIN + mitte - n * (dicke / 2)
		local p = Instance.new("Part")
		p.Name = "Rampe"
		p.Anchored = true
		p.Size = Vector3.new(laenge, dicke, math.sqrt(tiefe ^ 2 + hoehe ^ 2))
		p.CFrame = CFrame.lookAt(pos, pos + s)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if farbe then
			p.Color = farbe
			p.Material = material or Enum.Material.Concrete
		else
			p.Transparency = 1
			p.CastShadow = false
		end
		p.Parent = parent
		zaehler += 1
		return p
	end

	local function boden(parent, cx, cz, groesse, color, material)
		return box(parent, "Boden", Vector3.new(groesse, 0.06, groesse),
			Vector3.new(cx, BASIS + 0.03, cz), color, material, false)
	end

	local function scheibe(parent, cx, cz, durchmesser, color, material, ebene)
		return zylinder(parent, "Scheibe", 0.06, durchmesser,
			Vector3.new(cx, BASIS + 0.03 * ((ebene or 1) + 1), cz), color, material, false)
	end

	local function schild(parent, text, size, rel, farbe, textfarbe)
		local p = box(parent, "Schild", size, rel, farbe, Enum.Material.SmoothPlastic, false)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 30
			g.Parent = p
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = text
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = textfarbe or Color3.fromRGB(255, 255, 255)
			t.Parent = g
		end
		return p
	end

	local function baum(parent, x, z, skala)
		skala = skala or 1
		local h = rnd:NextNumber(8, 12) * skala
		local kr = rnd:NextNumber(10, 14) * skala
		zylinder(parent, "Stamm", h, 1.4 * skala, Vector3.new(x, BASIS + h / 2, z),
			Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
		kugel(parent, "Krone", kr, Vector3.new(x, BASIS + h + kr * 0.25, z),
			Color3.fromRGB(rnd:NextInteger(50, 80), rnd:NextInteger(120, 160), rnd:NextInteger(45, 70)),
			Enum.Material.Grass, false)
	end

	local function lampe(parent, x, z, mitLicht)
		local dunkel = Color3.fromRGB(45, 45, 50)
		zylinder(parent, "Sockel", 1, 2.2, Vector3.new(x, BASIS + 0.5, z), dunkel, Enum.Material.Metal)
		zylinder(parent, "Mast", 13, 0.8, Vector3.new(x, BASIS + 6.5, z), dunkel, Enum.Material.Metal)
		local kopf = box(parent, "Lampenkopf", Vector3.new(3, 0.5, 3),
			Vector3.new(x, BASIS + 13.25, z), Color3.fromRGB(255, 226, 170), Enum.Material.Neon, false)
		if mitLicht then
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 220, 160)
			l.Brightness = 1.4
			l.Range = 45
			l.Parent = kopf
		end
	end

	local AUTOFARBEN = {
		Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 90, 180), Color3.fromRGB(235, 235, 235),
		Color3.fromRGB(30, 30, 34), Color3.fromRGB(240, 190, 40), Color3.fromRGB(60, 150, 90),
		Color3.fromRGB(150, 150, 160),
	}

	local function auto(parent, x, z, yaw, farbe)
		local basis = CFrame.new(MAP_ORIGIN + Vector3.new(x, BASIS, z)) * CFrame.Angles(0, yaw, 0)
		local function teil(name, size, off, color, mat, collide, shape)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = basis * off
			p.Color = color
			p.Material = mat
			if shape then p.Shape = shape end
			if collide == false then p.CanCollide = false; p.CanQuery = false end
			p.Parent = parent
			zaehler += 1
			return p
		end
		teil("Karosserie", Vector3.new(4.6, 1.3, 2.2), CFrame.new(0, 1.15, 0), farbe, Enum.Material.SmoothPlastic)
		teil("Kabine", Vector3.new(2.4, 1, 2), CFrame.new(-0.2, 2.1, 0), Color3.fromRGB(40, 60, 80), Enum.Material.Glass, false)
		for _, wx in ipairs({ -1.5, 1.5 }) do
			for _, wz in ipairs({ -1.1, 1.1 }) do
				teil("Rad", Vector3.new(0.5, 1.1, 1.1), CFrame.new(wx, 0.55, wz) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(90), 0, 0),
					Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, false, Enum.PartType.Cylinder)
			end
		end
	end

	local function huetchen(parent, x, z)
		zylinder(parent, "Huetchen", 1, 1.3, Vector3.new(x, BASIS + 0.5, z), Color3.fromRGB(245, 110, 20), Enum.Material.SmoothPlastic, false)
		zylinder(parent, "Huetchen", 1, 0.85, Vector3.new(x, BASIS + 1.5, z), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, false)
		zylinder(parent, "Huetchen", 1, 0.5, Vector3.new(x, BASIS + 2.5, z), Color3.fromRGB(245, 110, 20), Enum.Material.SmoothPlastic, false)
	end

	local ASPHALT = Color3.fromRGB(48, 48, 52)
	local GEHWEG = Color3.fromRGB(176, 176, 172)
	local GRAS = Color3.fromRGB(86, 140, 68)
	local WEISS = Color3.fromRGB(240, 240, 240)
	local GELB = Color3.fromRGB(255, 210, 60)
	local richtungen = {
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	}
	local RAMPEN_HOEHE = BORDSTEIN_OBEN - STRASSE_OBEN
	local MY = STRASSE_OBEN + 0.03
	local raeder = {}

	local function schritt(name, fn)
		if MapSys.status and not windowClosed then
			MapSys.status:SetText("Baue " .. name .. " ...")
			setLabelColor(MapSys.status, COL.textDim)
		end
		local ok, err = pcall(fn)
		if not ok then warn("[LokaleMap] FEHLER in '" .. name .. "': " .. tostring(err)) end
		task.wait()
	end

	schritt("Boden und Strassen", function()
		box(fBoden, "Gras", Vector3.new(3400, 4, 3400), Vector3.new(0, -2, 0), GRAS, Enum.Material.Grass)
		for _, l in ipairs(LINIEN) do
			box(fStrassen, "Strasse", Vector3.new(STRASSEN_HALB * 2, 1, STRASSEN_BREITE),
				Vector3.new(0, STRASSE_OBEN - 0.5, l), ASPHALT, Enum.Material.Asphalt)
			box(fStrassen, "Strasse", Vector3.new(STRASSEN_BREITE, 1, STRASSEN_HALB * 2),
				Vector3.new(l, STRASSE_OBEN - 0.5, 0), ASPHALT, Enum.Material.Asphalt)
		end
		box(fStrassen, "ArenaBoden", Vector3.new(ARENA * 2, 1, ARENA * 2),
			Vector3.new(0, STRASSE_OBEN - 0.5, 0), ASPHALT, Enum.Material.Asphalt)
		local MAUER = STRASSEN_HALB + 3
		for _, d in ipairs(richtungen) do
			local quer = d.X ~= 0
			box(fStrassen, "Mauer",
				quer and Vector3.new(4, 5, MAUER * 2 + 8) or Vector3.new(MAUER * 2 + 8, 5, 4),
				d * MAUER + Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)
			box(fStrassen, "MauerStreifen",
				quer and Vector3.new(4.1, 1, MAUER * 2 + 8) or Vector3.new(MAUER * 2 + 8, 1, 4.1),
				d * MAUER + Vector3.new(0, 4, 0), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, false)
		end
	end)

	schritt("Markierungen", function()
		local function nahAnLinie(v)
			for _, m in ipairs(LINIEN) do
				if math.abs(v - m) <= 26 then return true end
			end
			return false
		end
		local function inArena(x, z)
			return math.abs(x) < ARENA - 1 and math.abs(z) < ARENA - 1
		end
		for _, l in ipairs(LINIEN) do
			for v = -608, 608, 16 do
				if not nahAnLinie(v) then
					if not inArena(v, l) then
						box(fMarkierung, "Mittellinie", Vector3.new(8, 0.05, 0.8), Vector3.new(v, MY, l), GELB, Enum.Material.SmoothPlastic, false)
					end
					if not inArena(l, v) then
						box(fMarkierung, "Mittellinie", Vector3.new(0.8, 0.05, 8), Vector3.new(l, MY, v), GELB, Enum.Material.SmoothPlastic, false)
					end
				end
			end
			for i = 1, #LINIEN - 1 do
				local a, b = LINIEN[i] + 26, LINIEN[i + 1] - 26
				local m, len = (a + b) / 2, b - a
				for _, o in ipairs({ -12, 12 }) do
					if not inArena(m, l) then
						box(fMarkierung, "Randlinie", Vector3.new(len, 0.05, 0.5), Vector3.new(m, MY, l + o), WEISS, Enum.Material.SmoothPlastic, false)
					end
					if not inArena(l, m) then
						box(fMarkierung, "Randlinie", Vector3.new(0.5, 0.05, len), Vector3.new(l + o, MY, m), WEISS, Enum.Material.SmoothPlastic, false)
					end
				end
			end
		end
		for _, lx in ipairs(LINIEN) do
			for _, lz in ipairs(LINIEN) do
				if not inArena(lx, lz) then
					for k = -14, 14, 4 do
						for _, d in ipairs(richtungen) do
							local off = 22
							if d.X ~= 0 then
								box(fMarkierung, "Zebra", Vector3.new(4, 0.05, 2), Vector3.new(lx + d.X * off, MY, lz + k), WEISS, Enum.Material.SmoothPlastic, false)
							else
								box(fMarkierung, "Zebra", Vector3.new(2, 0.05, 4), Vector3.new(lx + k, MY, lz + d.Z * off), WEISS, Enum.Material.SmoothPlastic, false)
							end
						end
					end
				end
			end
		end
	end)

	local function blockBasis(f, cx, cz, farbe, material)
		box(f, "Blockplatte", Vector3.new(BLOCK, 1.5, BLOCK), Vector3.new(cx, BORDSTEIN_OBEN - 0.75, cz), GEHWEG, Enum.Material.Concrete)
		boden(f, cx, cz, BLOCK - 16, farbe, material)
		for _, d in ipairs(richtungen) do
			schraege(fRampen, BLOCK, RAMPEN_HOEHE, RAMPEN_TIEFE, STRASSE_OBEN,
				Vector3.new(cx, 0, cz) + d * HB, -d, 1)
		end
		for _, sgn in ipairs({ -1, 1 }) do
			for _, t in ipairs({ -100, 0, 100 }) do
				lampe(f, cx + sgn * (HB - 6), cz + t, t == 0)
				lampe(f, cx + t, cz + sgn * (HB - 6), t == 0)
			end
		end
	end

	local function fensterband(f, size, rel)
		local an = rnd:NextNumber() < 0.35
		box(f, "Fenster", size, rel,
			an and Color3.fromRGB(255, 214, 140) or Color3.fromRGB(45, 65, 95),
			an and Enum.Material.Neon or Enum.Material.Glass, false)
	end

	local function turm(f, x, z, w, d, h, farbe, reklame)
		box(f, "Turm", Vector3.new(w, h, d), Vector3.new(x, BASIS + h / 2, z), farbe, Enum.Material.Concrete)
		box(f, "Dach", Vector3.new(w + 1, 1, d + 1), Vector3.new(x, BASIS + h + 0.5, z), Color3.fromRGB(60, 60, 66), Enum.Material.Slate)
		for fl = 1, math.floor(h / 8) do
			local y = BASIS + fl * 8 - 3
			fensterband(f, Vector3.new(w - 6, 3, 0.3), Vector3.new(x, y, z + d / 2 + 0.1))
			fensterband(f, Vector3.new(w - 6, 3, 0.3), Vector3.new(x, y, z - d / 2 - 0.1))
			fensterband(f, Vector3.new(0.3, 3, d - 6), Vector3.new(x + w / 2 + 0.1, y, z))
			fensterband(f, Vector3.new(0.3, 3, d - 6), Vector3.new(x - w / 2 - 0.1, y, z))
		end
		zylinder(f, "Antenne", 24, 0.8, Vector3.new(x, BASIS + h + 13, z), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
		kugel(f, "Warnlicht", 1.6, Vector3.new(x, BASIS + h + 25.5, z), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, false)
		if reklame then
			balken(f, Vector3.new(x - 8, BASIS + h + 1, z), Vector3.new(x - 8, BASIS + h + 6, z), 1, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
			balken(f, Vector3.new(x + 8, BASIS + h + 1, z), Vector3.new(x + 8, BASIS + h + 6, z), 1, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
			schild(f, reklame, Vector3.new(24, 9, 1), Vector3.new(x, BASIS + h + 10, z), Color3.fromRGB(20, 20, 30), Color3.fromRGB(255, 90, 160))
		end
	end

	local WOLKENKRATZER_NAMEN = { "HOTEL", "BANK", "CITY", "MEGA", "NEON", "TECH", "PLAZA", "SKY" }

	local function downtown(cx, cz, name, hoch)
		local f = ordner(name, map)
		blockBasis(f, cx, cz, Color3.fromRGB(125, 127, 133), Enum.Material.Concrete)
		local pos = { { -62, -62 }, { 62, -62 }, { -62, 62 }, { 62, 62 } }
		for i, p in ipairs(pos) do
			local h = rnd:NextInteger(70, 170)
			if hoch and i == 1 then h = 260 end
			local farbe = Color3.fromRGB(rnd:NextInteger(85, 150), rnd:NextInteger(95, 160), rnd:NextInteger(110, 175))
			turm(f, cx + p[1], cz + p[2], rnd:NextInteger(44, 58), rnd:NextInteger(44, 58), h, farbe,
				WOLKENKRATZER_NAMEN[rnd:NextInteger(1, #WOLKENKRATZER_NAMEN)])
		end
		for _ = 1, 10 do
			baum(f, cx + rnd:NextNumber(-110, 110) * 0.3 * ((rnd:NextInteger(0, 1) == 0) and 1 or -1), cz + rnd:NextNumber(-110, 110), 0.7)
		end
	end

	local function riesenrad(f, cx, cz)
		local R = 26
		local mitte = Vector3.new(cx, BASIS + R + 5, cz)
		local modell = Instance.new("Model")
		modell.Name = "Riesenrad"
		modell.Parent = f
		local nabe = zylinder(modell, "Nabe", 6, 4, mitte, Color3.fromRGB(200, 200, 205), Enum.Material.Metal, false)
		nabe.CFrame = CFrame.new(MAP_ORIGIN + mitte)
		modell.PrimaryPart = nabe
		local n = 24
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			local pos = mitte + Vector3.new(0, R * math.sin(a), R * math.cos(a))
			local seg = box(modell, "Ring", Vector3.new(1.2, 1.2, 2 * R * math.sin(math.pi / n) + 0.6), pos,
				Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, false)
			seg.CFrame = CFrame.lookAt(MAP_ORIGIN + pos, MAP_ORIGIN + pos + Vector3.new(0, math.cos(a), -math.sin(a)))
		end
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			balken(modell, mitte, mitte + Vector3.new(0, R * math.sin(a), R * math.cos(a)), 0.6,
				Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, false)
			local gp = mitte + Vector3.new(0, R * math.sin(a) - 1.8, R * math.cos(a))
			box(modell, "Gondel", Vector3.new(3, 3.2, 3.2), gp,
				Color3.fromHSV(i / 12, 0.75, 1), Enum.Material.SmoothPlastic, false)
		end
		for _, sx in ipairs({ -4, 4 }) do
			balken(f, Vector3.new(cx + sx, BASIS, cz - 22), mitte + Vector3.new(sx, 0, 0), 1.4, Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
			balken(f, Vector3.new(cx + sx, BASIS, cz + 22), mitte + Vector3.new(sx, 0, 0), 1.4, Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
		end
		table.insert(raeder, { modell = modell, mitte = mitte })
	end

	local function park(cx, cz, name, mitRad)
		local f = ordner(name, map)
		blockBasis(f, cx, cz, Color3.fromRGB(96, 156, 74), Enum.Material.Grass)
		local seeX, seeZ = -40, -35
		local see = scheibe(f, cx + seeX, cz + seeZ, 84, Color3.fromRGB(70, 150, 205), Enum.Material.Glass, 1)
		see.Transparency = 0.2
		boden(f, cx, cz, 0.1, GEHWEG, Enum.Material.Concrete).Size = Vector3.new(BLOCK - 16, 0.06, 8)
		local weg = boden(f, cx, cz, 0.1, GEHWEG, Enum.Material.Concrete)
		weg.Size = Vector3.new(8, 0.06, BLOCK - 16)
		weg.Position = weg.Position + Vector3.new(0, 0.03, 0)
		local versuche, anzahl = 0, 0
		while anzahl < 55 and versuche < 800 do
			versuche += 1
			local x = rnd:NextNumber(-118, 118)
			local z = rnd:NextNumber(-118, 118)
			local vomSee = math.sqrt((x - seeX) ^ 2 + (z - seeZ) ^ 2)
			local vomRad = math.sqrt((x - 75) ^ 2 + (z - 75) ^ 2)
			if vomSee > 52 and math.abs(x) > 9 and math.abs(z) > 9 and (not mitRad or vomRad > 40) then
				anzahl += 1
				baum(f, cx + x, cz + z)
			end
		end
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local bx, bz = cx + seeX + math.cos(a) * 49, cz + seeZ + math.sin(a) * 49
			if math.abs(bx - cx) > 9 and math.abs(bz - cz) > 9 then
				box(f, "Bank", Vector3.new(5, 1.2, 1.6), Vector3.new(bx, BASIS + 0.6, bz), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
			end
		end
		if mitRad then riesenrad(f, cx + 75, cz + 75) end
	end

	local function stadion(cx, cz)
		local f = ordner("Stadion", map)
		blockBasis(f, cx, cz, Color3.fromRGB(80, 80, 86), Enum.Material.Asphalt)
		scheibe(f, cx, cz, 196, Color3.fromRGB(55, 55, 60), Enum.Material.Asphalt, 1)
		scheibe(f, cx, cz, 104, Color3.fromRGB(65, 150, 60), Enum.Material.Grass, 2)
		scheibe(f, cx, cz, 54, Color3.fromRGB(75, 160, 68), Enum.Material.Grass, 3)
		local N = 36
		for i = 0, N - 1 do
			local a = i / N * math.pi * 2
			local grad = math.deg(a)
			local tor = (grad < 14 or grad > 346) or (math.abs(grad - 180) < 14)
			local tang = Vector3.new(-math.sin(a), 0, math.cos(a))
			if not tor then
				local R1, R2 = 104, 93
				local c1 = Vector3.new(cx + R1 * math.cos(a), BASIS + 9, cz + R1 * math.sin(a))
				local w1 = box(f, "Tribuene", Vector3.new(3, 18, 2 * R1 * math.sin(math.pi / N) + 0.8), c1,
					Color3.fromRGB(205, 205, 210), Enum.Material.Concrete)
				w1.CFrame = CFrame.lookAt(MAP_ORIGIN + c1, MAP_ORIGIN + c1 + tang)
				local c2 = Vector3.new(cx + R2 * math.cos(a), BASIS + 3, cz + R2 * math.sin(a))
				local w2 = box(f, "Sitzreihe", Vector3.new(5, 6, 2 * R2 * math.sin(math.pi / N) + 0.8), c2,
					(i % 2 == 0) and Color3.fromRGB(200, 45, 45) or Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
				w2.CFrame = CFrame.lookAt(MAP_ORIGIN + c2, MAP_ORIGIN + c2 + tang)
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = cx + sx * 114, cz + sz * 114
				zylinder(f, "Flutlichtmast", 46, 2, Vector3.new(x, BASIS + 23, z), Color3.fromRGB(110, 110, 118), Enum.Material.Metal)
				local lampeP = box(f, "Flutlicht", Vector3.new(10, 4, 3), Vector3.new(x, BASIS + 48, z), Color3.fromRGB(255, 255, 235), Enum.Material.Neon, false)
				local l = Instance.new("PointLight")
				l.Range = 60
				l.Brightness = 2
				l.Parent = lampeP
			end
		end
		for _, px in ipairs({ -16, 16 }) do
			zylinder(f, "Schildpfosten", 20, 1.2, Vector3.new(cx + px, BASIS + 10, cz - 115), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
		end
		schild(f, "STADION", Vector3.new(40, 8, 1), Vector3.new(cx, BASIS + 24, cz - 115), Color3.fromRGB(15, 15, 25), Color3.fromRGB(255, 200, 40))
	end

	local function industrie(cx, cz, name)
		local f = ordner(name, map)
		blockBasis(f, cx, cz, Color3.fromRGB(72, 74, 78), Enum.Material.Concrete)
		for i, p in ipairs({ { -62, -85 }, { 62, -85 }, { 0, -30 } }) do
			local w = i == 3 and 100 or 84
			box(f, "Halle", Vector3.new(w, 22, 40), Vector3.new(cx + p[1], BASIS + 11, cz + p[2]),
				Color3.fromRGB(135, 145, 158), Enum.Material.Metal)
			box(f, "Hallendach", Vector3.new(w + 2, 1.5, 42), Vector3.new(cx + p[1], BASIS + 22.5, cz + p[2]),
				Color3.fromRGB(85, 90, 100), Enum.Material.Metal)
			for k = -1, 1 do
				box(f, "Tor", Vector3.new(14, 12, 0.5), Vector3.new(cx + p[1] + k * 26, BASIS + 6, cz + p[2] + 20.2),
					Color3.fromRGB(235, 130, 35), Enum.Material.Metal, false)
			end
		end
		local cfarben = {
			Color3.fromRGB(200, 60, 50), Color3.fromRGB(40, 100, 170),
			Color3.fromRGB(230, 170, 40), Color3.fromRGB(60, 150, 90),
		}
		for i = 0, 5 do
			for j = 0, 1 do
				for lage = 1, rnd:NextInteger(1, 3) do
					box(f, "Container", Vector3.new(20, 5, 8),
						Vector3.new(cx - 85 + i * 30, BASIS + lage * 5 - 2.5, cz + 35 + j * 24),
						cfarben[rnd:NextInteger(1, #cfarben)], Enum.Material.Metal)
				end
			end
		end
		for _, x in ipairs({ -105, -90 }) do
			zylinder(f, "Schornstein", 70, 8, Vector3.new(cx + x, BASIS + 35, cz - 15), Color3.fromRGB(150, 85, 70), Enum.Material.Brick)
			zylinder(f, "SchornsteinStreifen", 4, 8.2, Vector3.new(cx + x, BASIS + 66, cz - 15), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, false)
			kugel(f, "Warnlicht", 1.6, Vector3.new(cx + x, BASIS + 71, cz - 15), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, false)
		end
		for k = 0, 2 do
			zylinder(f, "Tank", 20, 20, Vector3.new(cx + 100, BASIS + 10, cz - 10 + k * 32), Color3.fromRGB(215, 215, 220), Enum.Material.Metal)
		end
		local gelb = Color3.fromRGB(240, 190, 30)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				balken(f, Vector3.new(cx + 20 + sx * 22, BASIS, cz + 85 + sz * 8), Vector3.new(cx + 20 + sx * 22, BASIS + 34, cz + 85 + sz * 8), 2, gelb, Enum.Material.Metal)
			end
		end
		box(f, "Kranbruecke", Vector3.new(50, 3, 24), Vector3.new(cx + 20, BASIS + 35.5, cz + 85), gelb, Enum.Material.Metal)
		box(f, "Laufkatze", Vector3.new(6, 4, 6), Vector3.new(cx + 20, BASIS + 32, cz + 85), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, false)
	end

	local function wohnviertel(cx, cz, name)
		local f = ordner(name, map)
		blockBasis(f, cx, cz, Color3.fromRGB(110, 165, 85), Enum.Material.Grass)
		for k = -1, 1 do
			local w1 = boden(f, cx, cz, 10, Color3.fromRGB(130, 130, 135), Enum.Material.Asphalt)
			w1.Size = Vector3.new(BLOCK - 16, 0.06, 7)
			w1.Position = MAP_ORIGIN + Vector3.new(cx, BASIS + 0.06, cz + k * 80 + 28)
		end
		for ix = -1, 1 do
			for iz = -1, 1 do
				local x, z = cx + ix * 80, cz + iz * 80
				local w, d, h = rnd:NextInteger(22, 28), rnd:NextInteger(16, 20), rnd:NextInteger(10, 14)
				local farbe = Color3.fromHSV(rnd:NextNumber(0, 1), 0.25, 0.95)
				box(f, "Haus", Vector3.new(w, h, d), Vector3.new(x, BASIS + h / 2, z - 8), farbe, Enum.Material.SmoothPlastic)
				box(f, "Dach", Vector3.new(w + 3, 1, d + 3), Vector3.new(x, BASIS + h + 0.5, z - 8), Color3.fromRGB(110, 55, 45), Enum.Material.Slate)
				box(f, "Dach2", Vector3.new(w * 0.6, 3, d * 0.6), Vector3.new(x, BASIS + h + 2.5, z - 8), Color3.fromRGB(95, 48, 40), Enum.Material.Slate)
				box(f, "Tuer", Vector3.new(3.5, 6, 0.4), Vector3.new(x, BASIS + 3, z - 8 + d / 2 + 0.1), Color3.fromRGB(90, 55, 35), Enum.Material.Wood, false)
				for _, wx in ipairs({ -w / 4 - 2, w / 4 + 2 }) do
					box(f, "Fenster", Vector3.new(4, 4, 0.4), Vector3.new(x + wx, BASIS + h * 0.55, z - 8 + d / 2 + 0.1),
						(rnd:NextNumber() < 0.4) and Color3.fromRGB(255, 214, 140) or Color3.fromRGB(70, 100, 140),
						(rnd:NextNumber() < 0.4) and Enum.Material.Neon or Enum.Material.Glass, false)
				end
				baum(f, x + w / 2 + 6, z - 8 - d / 2, 0.7)
				if rnd:NextNumber() < 0.6 then
					auto(f, x, z + 14, math.rad(90), AUTOFARBEN[rnd:NextInteger(1, #AUTOFARBEN)])
				end
			end
		end
	end

	local function parkplatz(cx, cz, name)
		local f = ordner(name, map)
		blockBasis(f, cx, cz, Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt)
		for reihe = 0, 2 do
			local zr = cz - 85 + reihe * 40
			for i = 0, 11 do
				local x = cx - 110 + i * 10
				box(f, "Parklinie", Vector3.new(0.4, 0.05, 11), Vector3.new(x - 5, BASIS + 0.06, zr), WEISS, Enum.Material.SmoothPlastic, false)
				if rnd:NextNumber() < 0.55 then
					auto(f, x, zr + 0.5, math.rad(90), AUTOFARBEN[rnd:NextInteger(1, #AUTOFARBEN)])
				end
			end
			box(f, "Parklinie", Vector3.new(0.4, 0.05, 11), Vector3.new(cx + 10, BASIS + 0.06, zr), WEISS, Enum.Material.SmoothPlastic, false)
		end
		local tx, tz = cx, cz + 70
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				zylinder(f, "Pfeiler", 12, 1.6, Vector3.new(tx + sx * 18, BASIS + 6, tz + sz * 8), Color3.fromRGB(235, 235, 238), Enum.Material.Metal)
			end
		end
		box(f, "Vordach", Vector3.new(44, 1.6, 24), Vector3.new(tx, BASIS + 12.8, tz), Color3.fromRGB(235, 235, 238), Enum.Material.SmoothPlastic)
		box(f, "VordachLicht", Vector3.new(44.4, 0.6, 24.4), Vector3.new(tx, BASIS + 11.8, tz), Color3.fromRGB(220, 40, 40), Enum.Material.Neon, false)
		for _, px in ipairs({ -10, 10 }) do
			box(f, "Zapfsaeule", Vector3.new(1.6, 4, 1.2), Vector3.new(tx + px, BASIS + 2, tz), Color3.fromRGB(215, 40, 40), Enum.Material.SmoothPlastic)
			box(f, "ZapfsaeuleSchild", Vector3.new(1.4, 1.2, 1.3), Vector3.new(tx + px, BASIS + 3.5, tz), Color3.fromRGB(240, 240, 240), Enum.Material.Neon, false)
		end
		box(f, "Shop", Vector3.new(34, 10, 18), Vector3.new(tx, BASIS + 5, tz + 38), Color3.fromRGB(230, 230, 235), Enum.Material.SmoothPlastic)
		box(f, "ShopGlas", Vector3.new(28, 5, 0.4), Vector3.new(tx, BASIS + 4, tz + 38 - 9.1), Color3.fromRGB(120, 180, 220), Enum.Material.Glass, false)
		schild(f, "TANKSTELLE", Vector3.new(26, 4, 0.6), Vector3.new(tx, BASIS + 8.5, tz + 38 - 9.2), Color3.fromRGB(200, 30, 30), Color3.fromRGB(255, 255, 255))
		zylinder(f, "Mast", 22, 1.2, Vector3.new(tx + 55, BASIS + 11, tz - 5), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
		schild(f, "SUPER 1,99", Vector3.new(14, 6, 1), Vector3.new(tx + 55, BASIS + 23, tz - 5), Color3.fromRGB(15, 15, 25), Color3.fromRGB(80, 255, 120))
	end

	local function insel(cx, cz, R, mitBaeumen)
		zylinder(fArena, "Insel", 1.5, R * 2, Vector3.new(cx, BORDSTEIN_OBEN - 0.75, cz), GEHWEG, Enum.Material.Concrete)
		zylinder(fArena, "InselRasen", 0.06, R * 2 - 8, Vector3.new(cx, BORDSTEIN_OBEN + 0.03, cz),
			Color3.fromRGB(96, 156, 74), Enum.Material.Grass, false)
		local N = math.max(28, math.floor(R * 1.1))
		for k = 0, N - 1 do
			local a = (k + 0.5) / N * math.pi * 2
			local radial = Vector3.new(math.cos(a), 0, math.sin(a))
			local kante = Vector3.new(cx, 0, cz) + radial * (R - 1)
			schraege(fRampen, 2 * math.pi * (R + RAMPEN_TIEFE / 2) / N * 1.15, RAMPEN_HOEHE, RAMPEN_TIEFE,
				STRASSE_OBEN, kante, -radial, 1)
		end
		if mitBaeumen then
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2
				baum(fArena, cx + math.cos(a) * (R - 12), cz + math.sin(a) * (R - 12), 0.8)
			end
		end
	end

	local function arena()
		insel(0, 0, 45, false)
		scheibe(fArena, 0, 0, 40, Color3.fromRGB(225, 225, 225), Enum.Material.Marble, 1)
		zylinder(fArena, "Brunnenrand", 1.2, 22, Vector3.new(0, BASIS + 0.6, 0), Color3.fromRGB(225, 225, 225), Enum.Material.Marble)
		local wasser = zylinder(fArena, "Wasser", 0.2, 19, Vector3.new(0, BASIS + 1.2, 0), Color3.fromRGB(80, 170, 230), Enum.Material.Glass, false)
		wasser.Transparency = 0.35
		zylinder(fArena, "Saeule", 8, 1.6, Vector3.new(0, BASIS + 4, 0), Color3.fromRGB(225, 225, 225), Enum.Material.Marble)
		kugel(fArena, "Kugel", 4, Vector3.new(0, BASIS + 9, 0), Color3.fromRGB(120, 220, 255), Enum.Material.Neon, false)
		for k = 0, 47 do
			local a = k / 48 * math.pi * 2
			local p = Vector3.new(math.cos(a) * 62, MY, math.sin(a) * 62)
			local d = box(fMarkierung, "Ring", Vector3.new(0.6, 0.05, 6), p, WEISS, Enum.Material.SmoothPlastic, false)
			d.CFrame = CFrame.lookAt(MAP_ORIGIN + p, MAP_ORIGIN + p + Vector3.new(-math.sin(a), 0, math.cos(a)))
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				insel(sx * 150, sz * 150, 30, true)
			end
		end
		for _, sgn in ipairs({ -1, 1 }) do
			for k = 0, 9 do
				huetchen(fArena, sgn * (80 + k * 17), (k % 2 == 0) and 6 or -6)
			end
		end
		for k = 0, 5 do
			box(fMarkierung, "Pfeil", Vector3.new(1.4, 0.05, 6), Vector3.new(-20 + k * 8, MY, -90), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
		end
		local gelb, schwarz = Color3.fromRGB(255, 200, 30), Color3.fromRGB(35, 35, 38)
		local function schanze(lipX, lipZ, dir)
			schraege(fArena, 26, 8, 42, STRASSE_OBEN, Vector3.new(lipX, 0, lipZ), dir, 2, gelb, Enum.Material.Metal)
			local w = box(fArena, "Stuetze", Vector3.new(26, 8, 1), Vector3.new(lipX, STRASSE_OBEN + 4, lipZ) - dir * 0.5, schwarz, Enum.Material.Metal)
			w.CFrame = CFrame.lookAt(w.Position, w.Position + dir)
			local ziel = Vector3.new(lipX, 0, lipZ) + dir * 38
			schraege(fArena, 30, 6, 44, STRASSE_OBEN, ziel, -dir, 2, Color3.fromRGB(70, 200, 120), Enum.Material.Metal)
			local w2 = box(fArena, "Stuetze", Vector3.new(30, 6, 1), Vector3.new(ziel.X, STRASSE_OBEN + 3, ziel.Z) + dir * 0.5, schwarz, Enum.Material.Metal)
			w2.CFrame = CFrame.lookAt(w2.Position, w2.Position + dir)
		end
		schanze(-60, -222, Vector3.new(1, 0, 0))
		schanze(60, 222, Vector3.new(-1, 0, 0))
		schanze(-222, 60, Vector3.new(0, 0, -1))
		schanze(222, -60, Vector3.new(0, 0, 1))
	end

	schritt("Hochhaeuser 1", function() downtown(-450, -450, "Hochhaeuser_1", true) end)
	schritt("Park 1", function() park(-150, -450, "Park_1", false) end)
	schritt("Stadion", function() stadion(150, -450) end)
	schritt("Industrie 1", function() industrie(450, -450, "Industrie_1") end)
	schritt("Wohnviertel 1", function() wohnviertel(-450, -150, "Wohnviertel_1") end)
	schritt("Parkplatz 1", function() parkplatz(450, -150, "Parkplatz_1") end)
	schritt("Park 2 mit Riesenrad", function() park(-450, 150, "Park_2", true) end)
	schritt("Hochhaeuser 2", function() downtown(450, 150, "Hochhaeuser_2", false) end)
	schritt("Parkplatz 2", function() parkplatz(-450, 450, "Parkplatz_2") end)
	schritt("Industrie 2", function() industrie(-150, 450, "Industrie_2") end)
	schritt("Wohnviertel 2", function() wohnviertel(150, 450, "Wohnviertel_2") end)
	schritt("Hochhaeuser 3", function() downtown(450, 450, "Hochhaeuser_3", false) end)
	schritt("Arena", arena)

	schritt("Berge", function()
		for i = 0, 47 do
			local a = i / 48 * math.pi * 2 + rnd:NextNumber(-0.05, 0.05)
			local r = rnd:NextNumber(950, 1350)
			local s = rnd:NextNumber(250, 520)
			local berg = kugel(fBerge, "Berg", s, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
				Color3.fromRGB(rnd:NextInteger(95, 125), rnd:NextInteger(105, 130), rnd:NextInteger(105, 125)),
				Enum.Material.Rock, false)
			berg.Size = Vector3.new(s, s * rnd:NextNumber(0.45, 0.8), s)
			local kappe = kugel(fBerge, "Schnee", s * 0.45, Vector3.new(math.cos(a) * r, berg.Size.Y * 0.38, math.sin(a) * r),
				Color3.fromRGB(245, 248, 252), Enum.Material.Snow, false)
			kappe.Size = Vector3.new(s * 0.45, s * 0.2, s * 0.45)
		end
	end)

	MapSys.raeder = raeder
	local winkel = 0
	MapSys.wheelConn = RunService.Heartbeat:Connect(function(dt)
		winkel += dt * 0.25
		for _, r in ipairs(MapSys.raeder) do
			if r.modell and r.modell.Parent then
				r.modell:PivotTo(CFrame.new(MAP_ORIGIN + r.mitte) * CFrame.Angles(winkel, 0, 0))
			end
		end
	end)

	schritt("Beleuchtung", function()
		if LICHT_ANPASSEN then
			MapSys.lightingBackup = {
				ClockTime = Lighting.ClockTime,
				Brightness = Lighting.Brightness,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
			Lighting.ClockTime = 17.3
			Lighting.Brightness = 2.2
			Lighting.GlobalShadows = true
			Lighting.OutdoorAmbient = Color3.fromRGB(110, 115, 130)
			for _, n in ipairs({ "LokaleMapAtmosphere", "LokaleMapBloom" }) do
				local e = Lighting:FindFirstChild(n)
				if e then e:Destroy() end
			end
			local a = Instance.new("Atmosphere")
			a.Name = "LokaleMapAtmosphere"
			a.Density = 0.22
			a.Offset = 0.2
			a.Color = Color3.fromRGB(230, 205, 185)
			a.Decay = Color3.fromRGB(200, 150, 120)
			a.Glare = 0.3
			a.Haze = 1.2
			a.Parent = Lighting
			local bl = Instance.new("BloomEffect")
			bl.Name = "LokaleMapBloom"
			bl.Intensity = 0.3
			bl.Size = 24
			bl.Threshold = 1.6
			bl.Parent = Lighting
		end
	end)
end

-- -- ====================== TAB YEAT ======================
do
	local yeatTab = Window:Tab("Destroy Server")

	local mainSec = yeatTab:Section("Target Destroyer")

	local targetLabel = mainSec:Label({
		Text = "Target: None",
		Color = COL.textDim,
		TextSize = 13
	})

	local function getPlayerList()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				table.insert(list, plr.Name)
			end
		end
		table.sort(list)
		return list
	end

	local playerDropdown = mainSec:Dropdown({
		Text = "Select Target Player",
		Options = getPlayerList(),
		Default = "None",
		Callback = function(selectedName)
			if selectedName == "None" or selectedName == nil then
				yeatSelectedPlayer = nil
				targetLabel:SetText("Target: None")
				return
			end

			local plr = Players:FindFirstChild(selectedName)
			if plr then
				yeatSelectedPlayer = plr
				targetLabel:SetText("Target: " .. plr.Name)
			else
				yeatSelectedPlayer = nil
				targetLabel:SetText("Target: None")
			end
		end
	})

	local function refreshDropdown()
		if playerDropdown and playerDropdown.SetOptions then
			playerDropdown:SetOptions(getPlayerList())
		elseif playerDropdown and playerDropdown.Refresh then
			playerDropdown:Refresh(getPlayerList())
		end
	end

	Players.PlayerAdded:Connect(function()
		task.wait(0.5)
		refreshDropdown()
	end)
	Players.PlayerRemoving:Connect(function()
		task.wait(0.3)
		refreshDropdown()
		if yeatSelectedPlayer and not yeatSelectedPlayer.Parent then
			yeatSelectedPlayer = nil
			targetLabel:SetText("Target: None")
		end
	end)

	mainSec:Button({
		Text = "Refresh",
		Callback = function()
			refreshDropdown()
		end
	})

	mainSec:Toggle({
		Text = "Destroy",
		Default = false,
		Callback = function(val)
			yeatEnabled = val

			if val then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					yeatOriginalCFrame = hrp.CFrame
				end

				if yeatConn then yeatConn:Disconnect() end
				yeatConn = RunService.Heartbeat:Connect(function()
					if not yeatEnabled then return end
					if not yeatSelectedPlayer or not yeatSelectedPlayer.Character then return end

					local targetChar = yeatSelectedPlayer.Character
					local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
					local myChar = player.Character
					local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
					if not targetHRP or not myHRP then return end

					-- ===== SPECTATE STARK ERZWINGEN =====
					local cam = workspace.CurrentCamera
					cam.CameraType = Enum.CameraType.Custom
					if targetHum then
						cam.CameraSubject = targetHum
					end

					-- ===== KÖRPER DAUERHAFT UNTER DAS NÄCHSTE OBJECT ZUM TARGET =====
					local folder = workspace:FindFirstChild("PoliceNPCs")
					if folder then
						local bestPart, bestDist = nil, math.huge
						for _, obj in ipairs(folder:GetDescendants()) do
							if obj:IsA("BasePart") then
								local d = (obj.Position - targetHRP.Position).Magnitude
								if d < bestDist then
									bestDist = d
									bestPart = obj
								end
							end
						end

						if bestPart then
							-- Körper unter das Object setzen (funktioniert auch bei weiten Targets)
							myHRP.CFrame = CFrame.new(bestPart.Position - Vector3.new(0, 4, 0))
							myHRP.AssemblyLinearVelocity = Vector3.zero
							myHRP.AssemblyAngularVelocity = Vector3.zero
						end
					end

					-- ===== NPCs / AUTOS IN DIE PERSON ZIEHEN + UNSICHTBAR + KEINE KOLLISION =====
					if folder then
						for _, part in ipairs(folder:GetDescendants()) do
							if part:IsA("BasePart") then
								part.LocalTransparencyModifier = 1
								part.CanCollide = false
								part.CanTouch = false
								part.CanQuery = false
								part.Anchored = false

								local dir = (targetHRP.Position - part.Position)
								local dist = dir.Magnitude

								if dist > 4 then
									part.AssemblyLinearVelocity = dir.Unit * 1200 + Vector3.new(0, 15, 0)
								else
									if dist > 1.5 then
										part.AssemblyLinearVelocity = dir.Unit * 800 + Vector3.new(0, 20, 0)
									else
										part.AssemblyLinearVelocity = dir.Unit * 150 + Vector3.new(0, 5, 0)
									end
								end
							end
						end
					end
				end)
			else
				-- Ausschalten
				if yeatConn then
					yeatConn:Disconnect()
					yeatConn = nil
				end

				-- Transparenz & Kollision zurücksetzen
				local folder = workspace:FindFirstChild("PoliceNPCs")
				if folder then
					for _, part in ipairs(folder:GetDescendants()) do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = 0
							part.CanCollide = true
							part.CanTouch = true
							part.CanQuery = true
						end
					end
				end

				-- Zurück zur Original Position
				local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if myHRP and yeatOriginalCFrame then
					myHRP.CFrame = yeatOriginalCFrame
				end

				-- Kamera zurück
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
					workspace.CurrentCamera.CameraSubject = hum
				end
			end
		end
	})

	mainSec:Label({
		Text = "Destroy Target",
		Color = COL.textDim,
		TextSize = 12
	})
end

-- ====================== TAB CREDITS ======================
do
local creditsTab = Window:Tab("Credits")

local function addCreditCard(section, username, userId, role, roleColor)
	local content = creditsTab.Content
	if not content then
		section:Label({ Text = username, Color = roleColor or COL.text, TextSize = 15 })
		section:Label({ Text = role or "", Color = COL.textDim, TextSize = 11 })
		return
	end

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 64)
	row.BackgroundColor3 = COL.surface
	row.BorderSizePixel = 0
	row.LayoutOrder = creditsTab.NextOrder or 0
	if creditsTab.NextOrder then
		creditsTab.NextOrder = creditsTab.NextOrder + 1
	end
	row.Parent = content

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = COL.border
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.new(0, 48, 0, 48)
	avatar.Position = UDim2.new(0, 10, 0.5, -24)
	avatar.BackgroundColor3 = COL.surface2
	avatar.BorderSizePixel = 0
	avatar.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	avatar.Parent = row
	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(0, 10)
	avCorner.Parent = avatar
	local avStroke = Instance.new("UIStroke")
	avStroke.Color = roleColor or COL.accent
	avStroke.Thickness = 1.5
	avStroke.Transparency = 0.35
	avStroke.Parent = avatar

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -72, 0, 24)
	nameLbl.Position = UDim2.new(0, 68, 0, 10)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = username
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 15
	nameLbl.TextColor3 = roleColor or COL.text
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Parent = row

	local roleLbl = Instance.new("TextLabel")
	roleLbl.Size = UDim2.new(1, -72, 0, 18)
	roleLbl.Position = UDim2.new(0, 68, 0, 34)
	roleLbl.BackgroundTransparency = 1
	roleLbl.Text = role or ""
	roleLbl.Font = Enum.Font.Gotham
	roleLbl.TextSize = 12
	roleLbl.TextColor3 = COL.textDim
	roleLbl.TextXAlignment = Enum.TextXAlignment.Left
	roleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	roleLbl.Parent = row

	task.spawn(function()
		if not userId then return end
		local okThumb, contentUrl = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size60x60
			)
		end)
		if okThumb and contentUrl then
			avatar.Image = contentUrl
		end
		local okName, resolved = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if okName and resolved and resolved ~= "" then
			nameLbl.Text = resolved
		end
	end)
end

local ownerSec = creditsTab:Section("Owner")
addCreditCard(ownerSec, "xqrto", 3532767646, "Kuki Live · Feature GUI", COL.danger)

local coOwnerSec = creditsTab:Section("Co Owner")
addCreditCard(coOwnerSec, "tyx.l999", 9441899266, "Co Owner", COL.accent2)

local requestSec = creditsTab:Section("Script Request")
requestSec:Label({ Text = "auto farm with wheelie", Color = COL.accent, TextSize = 13 })
requestSec:Label({ Text = "Auto Money", Color = COL.accent, TextSize = 13 })
end

-- ====================== TAB ARROWS ======================
-- Pfeile in der Tab-Leiste: wechseln einen Tab vor/zurück und scrollen
-- die Leiste mit, damit der aktive Tab sichtbar bleibt.
local function createTabArrows()
	local tabBar = Window.TabBar
	if not tabBar then return end

	local tabList = Window.TabList
	if not tabList then
		tabList = tabBar:FindFirstChild("TabList", true)
	end
	local tabBarBg = tabList and tabList.Parent
	local canScroll = tabList ~= nil and tabBarBg ~= nil
	local scroll = 0
	local tabScrollTween = nil

	if canScroll then
		tabBarBg.ClipsDescendants = true
		-- Keep the list between the two arrow buttons. Scroll its canvas,
		-- not the whole ScrollingFrame; moving the frame itself caused the
		-- tabs to slide completely out of view when Credits was selected.
		tabList.Position = UDim2.new(0, 22, 0, 0)
		tabList.Size = UDim2.new(1, -60, 1, 0)
		tabList.CanvasPosition = Vector2.new(0, 0)
	end

	local function metrics()
		-- Use rendered widths (not only Size.X.Offset), since tab buttons may
		-- use scale sizing and their layout can change after selecting a tab.
		local widths, total = {}, 0
		for i, t in ipairs(Window.Tabs) do
			local w = 46
			if t.Button then
				w = math.max(1, t.Button.AbsoluteSize.X)
				if w <= 1 then w = t.Button.Size.X.Offset end
			end
			widths[i] = w
			total += w
		end
		if #Window.Tabs > 1 then total += (#Window.Tabs - 1) * 4 end
		return widths, total
	end

	local function apply()
		if not canScroll then return end
		local avail = tabList.AbsoluteSize.X
		local _, total = metrics()
		if avail <= 0 then return end
		-- Use the actual tab canvas width so the final tab cannot be
		-- overscrolled off-screen due to small layout/measurement differences.
		local canvasWidth = math.max(total, tabList.AbsoluteCanvasSize.X)
		local maxScroll = math.max(0, canvasWidth - avail)
		scroll = math.clamp(scroll, 0, maxScroll)
		if tabScrollTween then
			pcall(function() tabScrollTween:Cancel() end)
			tabScrollTween = nil
		end
		tabScrollTween = TweenService:Create(tabList, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CanvasPosition = Vector2.new(scroll, 0)
		})
		tabScrollTween:Play()
	end

	local function revealActive()
		if not canScroll then return end
		local avail = tabList.AbsoluteSize.X
		if avail <= 0 then return end
		local widths = metrics()
		local idx
		for i, t in ipairs(Window.Tabs) do
			if t == Window.ActiveTab then
				idx = i
				break
			end
		end
		if not idx then return end
		local start = 0
		for i = 1, idx - 1 do
			start += (widths[i] or 46) + 4
		end
		local stop = start + (widths[idx] or 46)
		if start < scroll then
			scroll = start
		elseif stop > scroll + avail then
			scroll = stop - avail
		end
		apply()
	end

	local function makeArrow(text, name, position)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AnchorPoint = Vector2.new(0, 0.5)
		btn.Position = position
		btn.Size = UDim2.fromOffset(24, 24)
		btn.BackgroundColor3 = COL.surface2
		btn.BackgroundTransparency = 0.1
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.TextColor3 = COL.text
		btn.ZIndex = 20
		btn.Parent = tabBar
		corner(btn, 8)
		stroke(btn, COL.accent, 1)
		return btn
	end

	local left = makeArrow("<", "TabArrowLeft", UDim2.new(0, 16, 0.5, 0))
	local right = makeArrow(">", "TabArrowRight", UDim2.new(1, -40, 0.5, 0))

	local function cycle(dir)
		local tabs = Window.Tabs
		if #tabs < 2 then return end
		local idx = 1
		for i, t in ipairs(tabs) do
			if t == Window.ActiveTab then
				idx = i
				break
			end
		end
		idx += dir
		if idx < 1 then
			idx = #tabs
		elseif idx > #tabs then
			idx = 1
		end
		Window:SelectTab(tabs[idx])
		task.defer(revealActive)
	end

	left.MouseButton1Click:Connect(function() cycle(-1) end)
	right.MouseButton1Click:Connect(function() cycle(1) end)

	for _, t in ipairs(Window.Tabs) do
		if t.Button then
			t.Button.MouseButton1Click:Connect(function()
				-- Let the library finish switching the content canvas first; then
				-- reveal the selected tab after the tab layout has settled.
				task.delay(0.05, revealActive)
				task.delay(0.18, revealActive)
			end)
		end
	end

	tabBar:GetPropertyChangedSignal("Visible"):Connect(function()
		if tabBar.Visible then
			task.defer(function()
				-- Recalculate after the bar has its final rendered size.
				apply()
				revealActive()
			end)
		end
	end)

	task.spawn(function()
		task.wait()
		revealActive()
	end)
end
createTabArrows()

-- ====================== CLEANUP ======================
local cleaned = false
cleanup = function()
	if cleaned then return end
	cleaned = true
	windowClosed = true

	stopAutoWheelie()
	stopSpeedBoost()
	pcall(destroySpeedTouchUI)
	stopFarmWheelie()
	stopAfkGlitch()
	stopAutoCollect()
	stopStayOnVehicle()
	pcall(unloadLokaleMap)

	if seatConn then seatConn:Disconnect(); seatConn = nil end
	if stateConn then stateConn:Disconnect(); stateConn = nil end
	if speedConn then speedConn:Disconnect(); speedConn = nil end

	_G.autoClaimWheelie = false
	_G.autoClaimTopSpeed = false
	_G.autoClaimPlaytime = false

	if policeConn then policeConn:Disconnect(); policeConn = nil end
	for k in pairs(worldState) do
		worldState[k] = true
		setVisible(k, true)
	end

	if casePopupGui and casePopupGui.Parent then
		casePopupGui:Destroy()
	end

	_G.KukiCleanup = nil
end
_G.KukiCleanup = cleanup

-- ====================== CHARACTER RESPAWN ======================
player.CharacterAdded:Connect(function()
	task.wait(1)
	lastVehicleSeat = nil
	manualDismount = false
	getCharacter()
	bindSeatTracking()
	if autoWheelieOn then startAutoWheelie() end
	if farmWheelieOn then startFarmWheelie() end
	if keepSeatedOn then startStayOnVehicle() end
	if SPEED_BOOST_ON then startSpeedBoost() end
	if afkGlitchOn then startAfkGlitch() end
end)

task.spawn(bindSeatTracking)

-- ====================== STARTUP SPLASH ======================
local splashParent = Window.MainFrame or Window.GuiRoot
if splashParent then
	task.spawn(function()
		local splash = Instance.new("Frame")
		splash.Size = UDim2.fromScale(1, 1)
		splash.BackgroundColor3 = COL.bg
		splash.BackgroundTransparency = 0.04
		splash.BorderSizePixel = 0
		splash.ClipsDescendants = true
		splash.ZIndex = 50
		splash.Parent = splashParent
		corner(splash, 16)

		local glow = Instance.new("Frame")
		glow.Size = UDim2.fromScale(1.4, 1.4)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundColor3 = COL.accent
		glow.BackgroundTransparency = 0.75
		glow.BorderSizePixel = 0
		glow.ZIndex = 50
		glow.Parent = splash
		corner(glow, 999)
		local glowGradient = Instance.new("UIGradient")
		glowGradient.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.65, 0.92),
			NumberSequenceKeypoint.new(1, 1),
		}
		glowGradient.Parent = glow

		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(180, 60)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = COL.surface
		card.BackgroundTransparency = 0.04
		card.BorderSizePixel = 0
		card.ZIndex = 51
		card.Parent = splash
		corner(card, 14)
		local cardStroke = stroke(card, COL.accent, 1.5)
		cardStroke.Transparency = 1

		local mini = Instance.new("TextLabel")
		mini.Size = UDim2.new(1, 0, 0, 16)
		mini.Position = UDim2.fromOffset(0, 14)
		mini.BackgroundTransparency = 1
		mini.Text = "KUKI LIVE"
		mini.TextColor3 = COL.textDim
		mini.TextTransparency = 1
		mini.TextSize = 10
		mini.Font = Enum.Font.GothamBold
		mini.ZIndex = 52
		mini.Parent = card

		local made = Instance.new("TextLabel")
		made.Size = UDim2.new(1, 0, 0, 30)
		made.Position = UDim2.fromOffset(0, 32)
		made.BackgroundTransparency = 1
		made.Text = "made by xqrto"
		made.TextColor3 = COL.text
		made.TextTransparency = 1
		made.TextSize = 22
		made.Font = Enum.Font.GothamBlack
		made.ZIndex = 52
		made.Parent = card
		local madeGradient = Instance.new("UIGradient")
		madeGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, COL.accent),
			ColorSequenceKeypoint.new(0.5, COL.text),
			ColorSequenceKeypoint.new(1, COL.accent2),
		}
		madeGradient.Parent = made

		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 0, 0, 2)
		line.Position = UDim2.new(0.5, 0, 0, 69)
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.BackgroundColor3 = COL.accent2
		line.BorderSizePixel = 0
		line.ZIndex = 52
		line.Parent = card
		corner(line, 2)

		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.fromOffset(250, 84)}):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
		TweenService:Create(made, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		TweenService:Create(mini, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
		TweenService:Create(line, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 120, 0, 2)}):Play()
		TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.fromScale(1.9, 1.9), BackgroundTransparency = 0.9}):Play()

		task.wait(1)

		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(splash, fade, {BackgroundTransparency = 1}):Play()
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{Size = UDim2.fromOffset(200, 66), BackgroundTransparency = 1}):Play()
		TweenService:Create(cardStroke, fade, {Transparency = 1}):Play()
		TweenService:Create(made, fade, {TextTransparency = 1}):Play()
		TweenService:Create(mini, fade, {TextTransparency = 1}):Play()
		TweenService:Create(line, fade, {BackgroundTransparency = 1}):Play()
		TweenService:Create(glow, fade, {BackgroundTransparency = 1}):Play()
		task.wait(0.4)
		splash:Destroy()
	end)
end

print("Kuki Live GUI geladen · Lib-Layout · Song-Discovery aktiv")

