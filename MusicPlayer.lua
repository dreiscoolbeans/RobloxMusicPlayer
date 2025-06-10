local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local mainFrame = script.Parent:WaitForChild("MainFrame")
local sound = mainFrame:WaitForChild("SoundPlayer", 5)

local soundIdInput = mainFrame:WaitForChild("SoundIdInput")
local loadButton = mainFrame:WaitForChild("LoadButton")
local playButton = mainFrame:WaitForChild("PlayButton")
local pauseButton = mainFrame:WaitForChild("PauseButton")

local progressBarBackground = mainFrame:WaitForChild("ProgressBarBackground")
local progressBarFill = progressBarBackground:WaitForChild("ProgressBarFill")
local progressThumb = mainFrame:WaitForChild("VolumeButton") -- This is the progress thumb (🔉 icon)

local volumeSliderBackground = mainFrame:WaitForChild("VolumeSliderBackground")
local volumeSliderFill = volumeSliderBackground:WaitForChild("VolumeSliderFill")
local volumeSliderThumb = volumeSliderBackground:WaitForChild("VolumeSliderThumb")

local songNameLabel = mainFrame:WaitForChild("SongNameLabel")
local artistLabel = mainFrame:WaitForChild("ArtistLabel")

local playing = false
local pausedTimePosition = 0
local currentAssetId = nil

-- Current volume (0 to 1)
local volume = sound.Volume

-- Update Play/Pause buttons visibility
local function updatePlayPauseButtons()
	if playing then
		playButton.Visible = false
		pauseButton.Visible = true
	else
		playButton.Visible = true
		pauseButton.Visible = false
	end
end

-- Update volume thumb position
local function updateVolumeThumb()
	local sliderWidth = volumeSliderBackground.AbsoluteSize.X
	local thumbWidth = volumeSliderThumb.AbsoluteSize.X
	local posX = (sliderWidth * volume) - (thumbWidth / 2)
	volumeSliderThumb.Position = UDim2.new(0, posX, volumeSliderThumb.Position.Y.Scale, volumeSliderThumb.Position.Y.Offset)
	volumeSliderFill.Size = UDim2.new(volume, 0, 1, 0)
end

-- Update song info from Roblox API
local function updateSongInfo(assetId)
	if not songNameLabel or not artistLabel then
		warn("SongNameLabel or ArtistLabel missing!")
		return
	end

	local url = "https://api.roblox.com/marketplace/productinfo?assetId=" .. assetId
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if success then
		local data = HttpService:JSONDecode(response)
		songNameLabel.Text = data.Name or "Unknown Title"
		if data.Creator and data.Creator.Name then
			artistLabel.Text = "By: " .. data.Creator.Name
		else
			artistLabel.Text = "By: Unknown Artist"
		end
	else
		songNameLabel.Text = "Unknown Title"
		artistLabel.Text = "By: Unknown Artist"
		warn("Failed to fetch song info for assetId " .. assetId)
	end
end

-- Load new sound by asset ID
loadButton.MouseButton1Click:Connect(function()
	local inputId = soundIdInput.Text:gsub("%D", "") -- digits only
	if #inputId > 0 then
		local assetIdNum = tonumber(inputId)
		if assetIdNum then
			if currentAssetId ~= assetIdNum then
				currentAssetId = assetIdNum
				sound.SoundId = "rbxassetid://" .. assetIdNum
				sound.TimePosition = 0
				pausedTimePosition = 0
				sound:Stop()
				sound:Play()
				playing = true
				updatePlayPauseButtons()
				updateSongInfo(assetIdNum)
			else
				print("Same SoundId already loaded")
			end
		else
			warn("Invalid SoundId entered: " .. tostring(inputId))
		end
	else
		warn("Please enter a valid SoundId")
	end
end)

-- Play button logic
playButton.MouseButton1Click:Connect(function()
	if not playing then
		sound.TimePosition = pausedTimePosition
		sound:Play()
		playing = true
		updatePlayPauseButtons()
	end
end)

-- Pause button logic
pauseButton.MouseButton1Click:Connect(function()
	if playing then
		pausedTimePosition = sound.TimePosition
		sound:Pause()
		playing = false
		updatePlayPauseButtons()
	end
end)

-- Update progress bar and progress thumb position every frame
RunService.Heartbeat:Connect(function()
	if sound.TimeLength > 0 and sound.IsPlaying then
		local progress = math.clamp(sound.TimePosition / sound.TimeLength, 0, 1)
		progressBarFill.Size = UDim2.new(progress, 0, 1, 0)

		local absPos = progressBarBackground.AbsolutePosition
		local absSize = progressBarBackground.AbsoluteSize

		local thumbWidth = progressThumb.AbsoluteSize.X
		local thumbX = absPos.X + progress * absSize.X - thumbWidth / 2
		local mainAbsPos = mainFrame.AbsolutePosition
		local relativeX = thumbX - mainAbsPos.X

		progressThumb.Position = UDim2.new(0, relativeX, progressThumb.Position.Y.Scale, progressThumb.Position.Y.Offset)
	else
		progressBarFill.Size = UDim2.new(0, 0, 1, 0)
		local absPos = progressBarBackground.AbsolutePosition
		local mainAbsPos = mainFrame.AbsolutePosition
		local relativeX = absPos.X - mainAbsPos.X - (progressThumb.AbsoluteSize.X / 2) + 1
		progressThumb.Position = UDim2.new(0, relativeX, progressThumb.Position.Y.Scale, progressThumb.Position.Y.Offset)
	end
end)

-- Handle dragging the progress thumb to seek in the song
local draggingProgress = false

progressThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingProgress = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingProgress = false
		sound.TimePosition = math.clamp(sound.TimePosition, 0, sound.TimeLength)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingProgress and input.UserInputType == Enum.UserInputType.MouseMovement then
		local mouseX = input.Position.X
		local barPos = progressBarBackground.AbsolutePosition.X
		local barSize = progressBarBackground.AbsoluteSize.X
		local relativeX = math.clamp(mouseX - barPos, 0, barSize)
		local progress = relativeX / barSize
		progressBarFill.Size = UDim2.new(progress, 0, 1, 0)

		local thumbWidth = progressThumb.AbsoluteSize.X
		local mainAbsPos = mainFrame.AbsolutePosition
		local thumbX = barPos + relativeX - thumbWidth / 2
		local relativeThumbX = thumbX - mainAbsPos.X
		progressThumb.Position = UDim2.new(0, relativeThumbX, progressThumb.Position.Y.Scale, progressThumb.Position.Y.Offset)

		if sound.TimeLength > 0 then
			sound.TimePosition = progress * sound.TimeLength
		end
	end
end)

-- Volume slider dragging logic
local draggingVolume = false

volumeSliderThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingVolume = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingVolume = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingVolume and input.UserInputType == Enum.UserInputType.MouseMovement then
		local mouseX = input.Position.X
		local barPos = volumeSliderBackground.AbsolutePosition.X
		local barSize = volumeSliderBackground.AbsoluteSize.X
		local relativeX = math.clamp(mouseX - barPos, 0, barSize)
		volume = relativeX / barSize
		sound.Volume = volume
		updateVolumeThumb()
	end
end)

-- Set initial visibility and thumb positions
updatePlayPauseButtons()
RunService.RenderStepped:Wait()
updateVolumeThumb()
