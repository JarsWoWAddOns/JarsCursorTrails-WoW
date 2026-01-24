-- Jar's Cursor Trail - Adds visual trails to mouse cursor
local addonName = "JarsCursorTrail"
local configFrame
local trailFrames = {}
local updateFrame
local lastX, lastY = 0, 0
local trailIndex = 1

-- Saved variables with defaults
JarsCursorTrailDB = JarsCursorTrailDB or {
    enabled = true,
    trailLength = 10,
    fadeTime = 0.5,
    updateInterval = 0.03,
    texture = "Star",
    size = 32,
    spacing = 20,
    offsetX = 0,
    offsetY = 0,
    color = {r = 1, g = 1, b = 1},
    alpha = 1.0,
    rainbowMode = false,
    gradientType = "Fire"
}

-- Available textures
local textures = {
    ["Star"] = "Interface\\Cooldown\\star4",
    ["Rune"] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Ring",
    ["Holy Glow"] = "Interface\\Cooldown\\ping4",
}

-- Gradient presets
local gradients = {
    ["Rainbow"] = function(position)
        -- HSV rainbow: position 0-1 maps to hue 0-360
        local hue = position * 360
        return HSVtoRGB(hue, 1, 1)
    end,
    ["Fire"] = function(position)
        -- Red → Orange → Yellow → Orange → Red
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        if t < 0.5 then
            return 1, t * 2, 0  -- Red to Orange
        else
            local s = (t - 0.5) * 2
            return 1, 1, s  -- Orange to Yellow
        end
    end,
    ["Ice"] = function(position)
        -- Cyan → Blue → Purple → Blue → Cyan
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        if t < 0.5 then
            local s = t * 2
            return 1-s, 1, 1  -- Cyan to Blue
        else
            local s = (t - 0.5) * 2
            return 0.5*s, 0, 1  -- Blue to Purple
        end
    end,
    ["Toxic"] = function(position)
        -- Green → Yellow → Green
        -- Mirror at halfway point for smooth pulse
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        return t, 1, 0
    end,
    ["Arcane"] = function(position)
        -- Purple → Pink → Blue → Pink → Purple
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        if t < 0.5 then
            local s = t * 2
            return 0.5 + s*0.5, 0, 1  -- Purple to Pink
        else
            local s = (t - 0.5) * 2
            return 1-s*0.5, 0, 1  -- Pink to Blue
        end
    end,
}

-- Convert HSV to RGB
local function HSVtoRGB(h, s, v)
    h = h % 360
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    
    local r, g, b
    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    
    return r + m, g + m, b + m
end

-- Get the current texture path
local function GetCurrentTexture()
    return textures[JarsCursorTrailDB.texture] or textures["Star"]
end

-- Get color for particle based on its position in trail
local function GetParticleColor(index, totalParticles)
    if not JarsCursorTrailDB.rainbowMode then
        return JarsCursorTrailDB.color.r, JarsCursorTrailDB.color.g, JarsCursorTrailDB.color.b
    end
    
    -- Calculate position in gradient (0 to 1)
    local position = (index - 1) / math.max(1, totalParticles - 1)
    
    -- Get gradient function
    local gradientFunc = gradients[JarsCursorTrailDB.gradientType] or gradients["Rainbow"]
    
    return gradientFunc(position)
end

-- Create trail particle
local function CreateTrailParticle(index)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(JarsCursorTrailDB.size, JarsCursorTrailDB.size)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(1000)
    frame:Hide()
    
    frame.texture = frame:CreateTexture(nil, "OVERLAY")
    frame.texture:SetAllPoints()
    frame.texture:SetTexture(GetCurrentTexture())
    frame.texture:SetBlendMode("ADD")
    
    -- Store particle index for gradient coloring
    frame.particleIndex = index
    
    -- Set initial color
    local r, g, b = GetParticleColor(index, JarsCursorTrailDB.trailLength)
    frame.texture:SetVertexColor(r, g, b, JarsCursorTrailDB.alpha)
    
    frame.startTime = 0
    frame.startAlpha = JarsCursorTrailDB.alpha
    frame.baseR = r
    frame.baseG = g
    frame.baseB = b
    
    return frame
end

-- Initialize trail frames pool
local function InitializeTrailFrames()
    -- Clear existing frames
    for _, frame in ipairs(trailFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    trailFrames = {}
    
    -- Create new pool with index for gradient
    for i = 1, JarsCursorTrailDB.trailLength do
        trailFrames[i] = CreateTrailParticle(i)
    end
end

-- Update trail particle positions and fade
local function UpdateTrail()
    if not JarsCursorTrailDB.enabled then return end
    
    -- Get cursor position
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    
    -- Calculate distance moved
    local dx = x - lastX
    local dy = y - lastY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Only create trail if moved enough
    if distance > JarsCursorTrailDB.spacing then
        local frame = trailFrames[trailIndex]
        
        if frame then
            -- Apply offset
            local offsetX = JarsCursorTrailDB.offsetX or 0
            local offsetY = JarsCursorTrailDB.offsetY or 0
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + offsetX, y + offsetY)
            
            -- Update color if rainbow mode
            local r, g, b = GetParticleColor(frame.particleIndex, JarsCursorTrailDB.trailLength)
            frame.baseR = r
            frame.baseG = g
            frame.baseB = b
            frame.texture:SetVertexColor(r, g, b, JarsCursorTrailDB.alpha)
            
            frame:Show()
            frame.startTime = GetTime()
            frame.startAlpha = JarsCursorTrailDB.alpha
        end
        
        -- Move to next frame
        trailIndex = trailIndex + 1
        if trailIndex > JarsCursorTrailDB.trailLength then
            trailIndex = 1
        end
        
        lastX, lastY = x, y
    end
    
    -- Update fade on all active frames
    local currentTime = GetTime()
    for _, frame in ipairs(trailFrames) do
        if frame:IsShown() then
            local elapsed = currentTime - frame.startTime
            local fadeProgress = elapsed / JarsCursorTrailDB.fadeTime
            
            if fadeProgress >= 1 then
                frame:Hide()
            else
                -- Fade out with easing
                local alpha = frame.startAlpha * (1 - fadeProgress)
                -- Maintain color while fading
                frame.texture:SetVertexColor(frame.baseR, frame.baseG, frame.baseB, alpha)
                
                -- Optional: scale down as it fades
                local scale = 1 - (fadeProgress * 0.3)
                frame:SetSize(
                    JarsCursorTrailDB.size * scale,
                    JarsCursorTrailDB.size * scale
                )
            end
        end
    end
end

-- Refresh all trail particles with current settings
local function RefreshTrailParticles()
    for _, frame in ipairs(trailFrames) do
        frame.texture:SetTexture(GetCurrentTexture())
        
        -- Update color based on mode
        local r, g, b = GetParticleColor(frame.particleIndex, JarsCursorTrailDB.trailLength)
        frame.baseR = r
        frame.baseG = g
        frame.baseB = b
        frame.texture:SetVertexColor(r, g, b, JarsCursorTrailDB.alpha)
        
        frame:SetSize(JarsCursorTrailDB.size, JarsCursorTrailDB.size)
    end
end

-- Create config window
local function CreateConfigWindow()
    if configFrame then return configFrame end
    
    configFrame = CreateFrame("Frame", "JarsCursorTrailConfig", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(400, 650)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
    configFrame.title:SetText("Jar's Cursor Trail Config")
    configFrame:Hide()
    
    local yOffset = -35
    
    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 20, yOffset)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableCheck.text:SetText("Enable Trail")
    enableCheck:SetChecked(JarsCursorTrailDB.enabled)
    enableCheck:SetScript("OnClick", function(self)
        JarsCursorTrailDB.enabled = self:GetChecked()
        if not JarsCursorTrailDB.enabled then
            -- Hide all trail particles
            for _, frame in ipairs(trailFrames) do
                frame:Hide()
            end
        end
    end)
    
    yOffset = yOffset - 40
    
    -- Trail length slider
    local lengthLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lengthLabel:SetPoint("TOPLEFT", 20, yOffset)
    lengthLabel:SetText("Trail Length:")
    
    local lengthSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    lengthSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    lengthSlider:SetMinMaxValues(5, 50)
    lengthSlider:SetValue(JarsCursorTrailDB.trailLength)
    lengthSlider:SetValueStep(1)
    lengthSlider:SetObeyStepOnDrag(true)
    lengthSlider:SetWidth(350)
    lengthSlider.Text:SetText("Trail Length: " .. JarsCursorTrailDB.trailLength)
    lengthSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.trailLength = math.floor(value)
        self.Text:SetText("Trail Length: " .. JarsCursorTrailDB.trailLength)
        InitializeTrailFrames()
    end)
    
    yOffset = yOffset - 60
    
    -- Fade time slider
    local fadeLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fadeLabel:SetPoint("TOPLEFT", 20, yOffset)
    fadeLabel:SetText("Fade Duration:")
    
    local fadeSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    fadeSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    fadeSlider:SetMinMaxValues(0.1, 2.0)
    fadeSlider:SetValue(JarsCursorTrailDB.fadeTime)
    fadeSlider:SetValueStep(0.1)
    fadeSlider:SetObeyStepOnDrag(true)
    fadeSlider:SetWidth(350)
    fadeSlider.Text:SetText(string.format("Fade: %.1fs", JarsCursorTrailDB.fadeTime))
    fadeSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.fadeTime = value
        self.Text:SetText(string.format("Fade: %.1fs", value))
    end)
    
    yOffset = yOffset - 60
    
    -- Particle size slider
    local sizeLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 20, yOffset)
    sizeLabel:SetText("Particle Size:")
    
    local sizeSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    sizeSlider:SetMinMaxValues(16, 64)
    sizeSlider:SetValue(JarsCursorTrailDB.size)
    sizeSlider:SetValueStep(4)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(350)
    sizeSlider.Text:SetText("Size: " .. JarsCursorTrailDB.size)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.size = math.floor(value)
        self.Text:SetText("Size: " .. JarsCursorTrailDB.size)
        RefreshTrailParticles()
    end)
    
    yOffset = yOffset - 60
    
    -- Spacing slider
    local spacingLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", 20, yOffset)
    spacingLabel:SetText("Trail Spacing:")
    
    local spacingSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    spacingSlider:SetMinMaxValues(5, 50)
    spacingSlider:SetValue(JarsCursorTrailDB.spacing)
    spacingSlider:SetValueStep(5)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetWidth(350)
    spacingSlider.Text:SetText("Spacing: " .. JarsCursorTrailDB.spacing)
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.spacing = math.floor(value)
        self.Text:SetText("Spacing: " .. JarsCursorTrailDB.spacing)
    end)
    
    yOffset = yOffset - 50
    
    -- X/Y Offset sliders side-by-side
    local offsetLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetLabel:SetPoint("TOPLEFT", 20, yOffset)
    offsetLabel:SetText("Trail Offset:")
    
    -- X Offset slider
    local offsetXSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    offsetXSlider:SetMinMaxValues(-50, 50)
    offsetXSlider:SetValue(JarsCursorTrailDB.offsetX or 0)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    offsetXSlider:SetWidth(150)
    offsetXSlider.Text:SetText("X: " .. (JarsCursorTrailDB.offsetX or 0))
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.offsetX = math.floor(value)
        self.Text:SetText("X: " .. JarsCursorTrailDB.offsetX)
    end)
    
    -- Y Offset slider (side-by-side with X)
    local offsetYSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("LEFT", offsetXSlider, "RIGHT", 30, 0)
    offsetYSlider:SetMinMaxValues(-50, 50)
    offsetYSlider:SetValue(JarsCursorTrailDB.offsetY or 0)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    offsetYSlider:SetWidth(150)
    offsetYSlider.Text:SetText("Y: " .. (JarsCursorTrailDB.offsetY or 0))
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.offsetY = math.floor(value)
        self.Text:SetText("Y: " .. JarsCursorTrailDB.offsetY)
    end)
    
    yOffset = yOffset - 50
    
    -- Texture dropdown
    local textureLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textureLabel:SetPoint("TOPLEFT", 20, yOffset)
    textureLabel:SetText("Trail Effect:")
    
    local textureDropdown = CreateFrame("Frame", nil, configFrame, "UIDropDownMenuTemplate")
    textureDropdown:SetPoint("TOPLEFT", 10, yOffset - 25)
    
    UIDropDownMenu_SetWidth(textureDropdown, 150)
    UIDropDownMenu_SetText(textureDropdown, JarsCursorTrailDB.texture)
    
    local function TextureDropdown_OnClick(self)
        JarsCursorTrailDB.texture = self.value
        UIDropDownMenu_SetText(textureDropdown, self.value)
        RefreshTrailParticles()
    end
    
    local function TextureDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for name, _ in pairs(textures) do
            info.text = name
            info.value = name
            info.func = TextureDropdown_OnClick
            info.checked = (JarsCursorTrailDB.texture == name)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(textureDropdown, TextureDropdown_Initialize)
    
    yOffset = yOffset - 65
    
    -- Color pickers
    local colorLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", 20, yOffset)
    colorLabel:SetText("Trail Color:")
    
    local colorButton = CreateFrame("Button", nil, configFrame)
    colorButton:SetSize(80, 25)
    colorButton:SetPoint("TOPLEFT", 120, yOffset)
    
    colorButton.texture = colorButton:CreateTexture(nil, "BACKGROUND")
    colorButton.texture:SetAllPoints()
    colorButton.texture:SetColorTexture(
        JarsCursorTrailDB.color.r,
        JarsCursorTrailDB.color.g,
        JarsCursorTrailDB.color.b
    )
    
    colorButton:SetScript("OnClick", function(self)
        local info = {
            r = JarsCursorTrailDB.color.r,
            g = JarsCursorTrailDB.color.g,
            b = JarsCursorTrailDB.color.b,
            opacity = JarsCursorTrailDB.alpha,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                JarsCursorTrailDB.color.r = r
                JarsCursorTrailDB.color.g = g
                JarsCursorTrailDB.color.b = b
                self.texture:SetColorTexture(r, g, b)
                RefreshTrailParticles()
            end,
            cancelFunc = function(prev)
                JarsCursorTrailDB.color.r = prev.r
                JarsCursorTrailDB.color.g = prev.g
                JarsCursorTrailDB.color.b = prev.b
                self.texture:SetColorTexture(prev.r, prev.g, prev.b)
                RefreshTrailParticles()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    
    -- Set initial state based on rainbow mode
    if JarsCursorTrailDB.rainbowMode then
        colorButton:Disable()
        colorButton:SetAlpha(0.5)
        colorLabel:SetTextColor(0.5, 0.5, 0.5)
    end
    
    yOffset = yOffset - 40
    
    -- Rainbow mode checkbox
    local rainbowCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    rainbowCheck:SetPoint("TOPLEFT", 20, yOffset)
    rainbowCheck:SetChecked(JarsCursorTrailDB.rainbowMode)
    rainbowCheck.Text = rainbowCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rainbowCheck.Text:SetPoint("LEFT", rainbowCheck, "RIGHT", 5, 0)
    rainbowCheck.Text:SetText("Rainbow/Gradient Mode")
    rainbowCheck:SetScript("OnClick", function(self)
        JarsCursorTrailDB.rainbowMode = self:GetChecked()
        RefreshTrailParticles()
        -- Enable/disable color button and gradient dropdown
        if JarsCursorTrailDB.rainbowMode then
            colorButton:Disable()
            colorButton:SetAlpha(0.5)
            colorLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            colorButton:Enable()
            colorButton:SetAlpha(1)
            colorLabel:SetTextColor(1, 1, 1)
        end
    end)
    
    yOffset = yOffset - 35
    
    -- Gradient type dropdown (only visible in rainbow mode)
    local gradientLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gradientLabel:SetPoint("TOPLEFT", 20, yOffset)
    gradientLabel:SetText("Gradient Type:")
    
    local gradientDropdown = CreateFrame("Frame", nil, configFrame, "UIDropDownMenuTemplate")
    gradientDropdown:SetPoint("TOPLEFT", 10, yOffset - 25)
    
    UIDropDownMenu_SetWidth(gradientDropdown, 150)
    UIDropDownMenu_SetText(gradientDropdown, JarsCursorTrailDB.gradientType)
    
    local function GradientDropdown_OnClick(self)
        JarsCursorTrailDB.gradientType = self.value
        UIDropDownMenu_SetText(gradientDropdown, self.value)
        RefreshTrailParticles()
    end
    
    local function GradientDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local gradientNames = {"Fire", "Ice", "Toxic", "Arcane"}
        for _, name in ipairs(gradientNames) do
            info.text = name
            info.value = name
            info.func = GradientDropdown_OnClick
            info.checked = (JarsCursorTrailDB.gradientType == name)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(gradientDropdown, GradientDropdown_Initialize)
    
    yOffset = yOffset - 65
    
    -- Alpha slider
    local alphaLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", 20, yOffset)
    alphaLabel:SetText("Opacity:")
    
    local alphaSlider = CreateFrame("Slider", nil, configFrame, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 20, yOffset - 20)
    alphaSlider:SetMinMaxValues(0.1, 1.0)
    alphaSlider:SetValue(JarsCursorTrailDB.alpha)
    alphaSlider:SetValueStep(0.1)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(350)
    alphaSlider.Text:SetText(string.format("Opacity: %.1f", JarsCursorTrailDB.alpha))
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        JarsCursorTrailDB.alpha = value
        self.Text:SetText(string.format("Opacity: %.1f", value))
        RefreshTrailParticles()
    end)
    
    yOffset = yOffset - 60
    
    -- Reset button
    local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 25)
    resetButton:SetPoint("BOTTOMLEFT", 20, 20)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", function()
        JarsCursorTrailDB.enabled = true
        JarsCursorTrailDB.trailLength = 10
        JarsCursorTrailDB.fadeTime = 0.5
        JarsCursorTrailDB.texture = "Star"
        JarsCursorTrailDB.size = 32
        JarsCursorTrailDB.spacing = 20
        JarsCursorTrailDB.offsetX = 0
        JarsCursorTrailDB.offsetY = 0
        JarsCursorTrailDB.color = {r = 1, g = 1, b = 1}
        JarsCursorTrailDB.alpha = 1.0
        JarsCursorTrailDB.rainbowMode = false
        JarsCursorTrailDB.gradientType = "Fire"
        
        -- Update UI
        enableCheck:SetChecked(true)
        rainbowCheck:SetChecked(false)
        lengthSlider:SetValue(10)
        fadeSlider:SetValue(0.5)
        sizeSlider:SetValue(32)
        spacingSlider:SetValue(20)
        offsetXSlider:SetValue(0)
        offsetYSlider:SetValue(0)
        alphaSlider:SetValue(1.0)
        UIDropDownMenu_SetText(textureDropdown, "Star")
        UIDropDownMenu_SetText(gradientDropdown, "Fire")
        colorButton.texture:SetColorTexture(1, 1, 1)
        colorButton:Enable()
        colorButton:SetAlpha(1)
        colorLabel:SetTextColor(1, 1, 1)
        
        InitializeTrailFrames()
        RefreshTrailParticles()
        print("JarsCursorTrail: Settings reset to defaults")
    end)
    
    return configFrame
end

-- Initialize addon
local function Initialize()
    -- Initialize trail frames
    InitializeTrailFrames()
    
    -- Create update frame
    updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        UpdateTrail()
    end)
    
    print("|cff00ff00Jar's Cursor Trail loaded! Type |r|cffFFFF00/jct|r|cff00ff00 to configure.|r")
end

-- Slash commands
SLASH_JARSCURSORTRAIL1 = "/jct"
SLASH_JARSCURSORTRAIL2 = "/cursortrail"
SlashCmdList["JARSCURSORTRAIL"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "toggle" then
        JarsCursorTrailDB.enabled = not JarsCursorTrailDB.enabled
        print("JarsCursorTrail: " .. (JarsCursorTrailDB.enabled and "Enabled" or "Disabled"))
    else
        local frame = CreateConfigWindow()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
