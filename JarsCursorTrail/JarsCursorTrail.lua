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
    gradientType = "Fire",
    customColor1 = {r = 1, g = 0, b = 0},
    customColor2 = {r = 1, g = 1, b = 0},
    customColor3 = {r = 0, g = 0, b = 1}
}

-- Initialize new fields for existing users
JarsCursorTrailDB.customColor1 = JarsCursorTrailDB.customColor1 or {r = 1, g = 0, b = 0}
JarsCursorTrailDB.customColor2 = JarsCursorTrailDB.customColor2 or {r = 1, g = 1, b = 0}
JarsCursorTrailDB.customColor3 = JarsCursorTrailDB.customColor3 or {r = 0, g = 0, b = 1}

-- Modern dark UI color palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 0.30, 0.75, 0.75, 1 },
    accentDim = { 0.20, 0.50, 0.50, 1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 0.30, 0.75, 0.75, 0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 0.30, 0.75, 0.75, 1 },
    checkOff  = { 0.22, 0.22, 0.26, 1 },
}

local modernBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- Available textures
local textures = {
    ["Star"] = "Interface\\Cooldown\\star4",
    ["Rune"] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Ring",
    ["Holy Glow"] = "Interface\\Cooldown\\ping4",
    ["Diamond"] = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    
    -- From CursorTrail addon (FileDataIDs work with WoW 12.0)
    ["Bug (Blue)"] = 605711,
    ["Bug (Orange)"] = 2447131,
    ["Frame (Gold)"] = 237701,
    ["Frame (Gold 3D)"] = 618870,
    ["Glow (Gold)"] = 607860,
    ["Glyph (Green)"] = 136841,
    ["Ring (Arcane)"] = "Interface\\UnitPowerBarAlt\\Arcane_Circular_Frame",
    ["Ring (Fire)"] = "Interface\\UnitPowerBarAlt\\Fire_Circular_Frame",
    ["Ring (Gold)"] = 519888,
    ["Ring (Gradient 1)"] = 4734120,
    ["Ring (Gradient 5)"] = 4734114,
    ["Ring (Horde)"] = 457585,
    ["Ring (Ice)"] = 458995,
    ["Shield (Alliance)"] = 457561,
    ["Shield (Gold)"] = 607858,
}

-- Convert HSV to RGB (needed by Rainbow gradient)
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
        -- Cyan → White → Cyan (frosty)
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        -- Interpolate from cyan (0,1,1) to white (1,1,1)
        local r = t
        return r, 1, 1
    end,
    ["Toxic"] = function(position)
        -- Green → Yellow → Green
        -- Mirror at halfway point for smooth pulse
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        return t, 1, 0
    end,
    ["Arcane"] = function(position)
        -- Purple → Magenta → Purple (arcane magic)
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        -- Interpolate from purple (0.5,0,1) to magenta (1,0,1)
        local r = 0.5 + (t * 0.5)
        return r, 0, 1
    end,
    ["Custom"] = function(position)
        -- Blend between 3 custom colors: Color1 → Color2 → Color3 → Color2 → Color1
        -- Mirror at halfway point
        local t = position <= 0.5 and (position * 2) or (2 - position * 2)
        
        local c1 = JarsCursorTrailDB.customColor1
        local c2 = JarsCursorTrailDB.customColor2
        local c3 = JarsCursorTrailDB.customColor3
        
        if t < 0.5 then
            -- Blend from color1 to color2
            local blend = t * 2
            return c1.r + (c2.r - c1.r) * blend,
                   c1.g + (c2.g - c1.g) * blend,
                   c1.b + (c2.b - c1.b) * blend
        else
            -- Blend from color2 to color3
            local blend = (t - 0.5) * 2
            return c2.r + (c3.r - c2.r) * blend,
                   c2.g + (c3.g - c2.g) * blend,
                   c2.b + (c3.b - c2.b) * blend
        end
    end,
}

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
    
    -- Store particle index for gradient coloring
    frame.particleIndex = index
    
    -- Create texture
    frame.texture = frame:CreateTexture(nil, "OVERLAY")
    frame.texture:SetAllPoints()
    frame.texture:SetTexture(GetCurrentTexture())
    frame.texture:SetBlendMode("ADD")
    
    -- Set initial color
    local r, g, b = GetParticleColor(index, JarsCursorTrailDB.trailLength)
    frame.texture:SetVertexColor(r, g, b, JarsCursorTrailDB.alpha)
    
    frame.baseR = r
    frame.baseG = g
    frame.baseB = b
    
    frame.startTime = 0
    frame.startAlpha = JarsCursorTrailDB.alpha
    
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
            
            -- Update color for gradient mode
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
                
                -- Maintain color while fading textures
                if frame.texture then
                    frame.texture:SetVertexColor(frame.baseR, frame.baseG, frame.baseB, alpha)
                end
                
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
        -- Update texture
        if frame.texture then
            frame.texture:SetTexture(GetCurrentTexture())
            
            -- Update color based on gradient mode
            local r, g, b = GetParticleColor(frame.particleIndex, JarsCursorTrailDB.trailLength)
            frame.baseR = r
            frame.baseG = g
            frame.baseB = b
            frame.texture:SetVertexColor(r, g, b, JarsCursorTrailDB.alpha)
        end
        
        frame:SetSize(JarsCursorTrailDB.size, JarsCursorTrailDB.size)
    end
end

-- Helper: Modern slider
local function CreateModernSlider(parent, name, labelText, minVal, maxVal, curVal, step, width, formatFunc, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 40)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(unpack(UI.text))
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)

    local valueText = container:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    valueText:SetTextColor(unpack(UI.accent))
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetText(formatFunc(curVal))

    local slider = CreateFrame("Slider", name, container, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetSize(width, 14)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(curVal)

    -- Track background
    local trackBg = slider:CreateTexture(nil, "BACKGROUND")
    trackBg:SetPoint("LEFT", 0, 0)
    trackBg:SetPoint("RIGHT", 0, 0)
    trackBg:SetHeight(4)
    trackBg:SetColorTexture(unpack(UI.sliderBg))

    -- Fill texture
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(UI.sliderFill))

    -- Thumb
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(14, 14)
        thumb:SetColorTexture(unpack(UI.accent))
    end

    local function UpdateFill()
        local min, max = slider:GetMinMaxValues()
        local val = slider:GetValue()
        local pct = (val - min) / (max - min)
        fill:SetWidth(math.max(1, pct * width))
    end
    UpdateFill()

    slider:SetScript("OnValueChanged", function(self, value)
        valueText:SetText(formatFunc(value))
        UpdateFill()
        onChange(value)
    end)

    container.slider = slider
    container.valueText = valueText
    container.label = label
    return container
end

-- Helper: Modern checkbox
local function CreateModernCheck(parent, labelText, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 20)

    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(modernBackdrop)
    box:SetBackdropColor(unpack(checked and UI.checkOn or UI.checkOff))
    box:SetBackdropBorderColor(unpack(UI.border))

    local mark = box:CreateFontString(nil, "OVERLAY")
    mark:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetTextColor(unpack(UI.bg))
    mark:SetText(checked and "\226\156\147" or "")

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(unpack(UI.text))
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(labelText)

    local state = checked and true or false

    local hitArea = CreateFrame("Button", nil, container)
    hitArea:SetAllPoints(container)
    hitArea:SetScript("OnClick", function()
        state = not state
        box:SetBackdropColor(unpack(state and UI.checkOn or UI.checkOff))
        mark:SetText(state and "\226\156\147" or "")
        if onClick then onClick(state) end
    end)

    container.SetChecked = function(_, val)
        state = val and true or false
        box:SetBackdropColor(unpack(state and UI.checkOn or UI.checkOff))
        mark:SetText(state and "\226\156\147" or "")
    end
    container.GetChecked = function(_) return state end

    return container
end

-- Helper: Modern button
local function CreateModernButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(modernBackdrop)
    btn:SetBackdropColor(unpack(UI.btnNormal))
    btn:SetBackdropBorderColor(unpack(UI.border))

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    btn.label:SetTextColor(unpack(UI.text))
    btn.label:SetPoint("CENTER", 0, 0)
    btn.label:SetText(text)

    btn.SetText = function(_, t) btn.label:SetText(t) end

    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(UI.btnHover)) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(UI.btnNormal)) end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(unpack(UI.btnPress)) end)
    btn:SetScript("OnMouseUp", function(self) self:SetBackdropColor(unpack(UI.btnHover)) end)
    btn:SetScript("OnClick", onClick)

    return btn
end

-- Helper: Section header
local function CreateSectionHeader(parent, text)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(parent:GetWidth() or 380, 20)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    label:SetTextColor(unpack(UI.textDim))
    label:SetPoint("LEFT", 0, 0)
    label:SetText(string.upper(text))

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    line:SetColorTexture(unpack(UI.border))

    return container
end

-- Create config window
local function CreateConfigWindow()
    if configFrame then return configFrame end
    
    -- Initialize custom colors if missing (for existing users)
    JarsCursorTrailDB.customColor1 = JarsCursorTrailDB.customColor1 or {r = 1, g = 0, b = 0}
    JarsCursorTrailDB.customColor2 = JarsCursorTrailDB.customColor2 or {r = 1, g = 1, b = 0}
    JarsCursorTrailDB.customColor3 = JarsCursorTrailDB.customColor3 or {r = 0, g = 0, b = 1}
    
    configFrame = CreateFrame("Frame", "JarsCursorTrailConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(460, 700)
    configFrame:SetPoint("CENTER")
    configFrame:SetBackdrop(modernBackdrop)
    configFrame:SetBackdropColor(unpack(UI.bg))
    configFrame:SetBackdropBorderColor(unpack(UI.border))
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:Hide()
    tinsert(UISpecialFrames, "JarsCursorTrailConfig")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop(modernBackdrop)
    titleBar:SetBackdropColor(unpack(UI.header))
    titleBar:SetBackdropBorderColor(unpack(UI.border))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    titleText:SetTextColor(unpack(UI.accent))
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetText("Jar's Cursor Trail")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("RIGHT", -2, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    closeTxt:SetTextColor(unpack(UI.textDim))
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4, 1) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(unpack(UI.textDim)) end)
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(390, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local contentWidth = 380
    local yOff = 0
    local function nextY(h) yOff = yOff - h; return yOff end
    local contentWidth = 380
    local yOff = 0
    local function nextY(h) yOff = yOff - h; return yOff end

    -- =====================
    -- GENERAL SECTION
    -- =====================
    local sec1 = CreateSectionHeader(scrollChild, "General")
    sec1:SetSize(contentWidth, 20)
    sec1:SetPoint("TOPLEFT", 0, nextY(0))

    local enableCheck = CreateModernCheck(scrollChild, "Enable Trail", JarsCursorTrailDB.enabled, function(val)
        JarsCursorTrailDB.enabled = val
        if not val then
            for _, frame in ipairs(trailFrames) do
                frame:Hide()
            end
        end
    end)
    enableCheck:SetPoint("TOPLEFT", 0, nextY(28))

    -- =====================
    -- APPEARANCE SECTION
    -- =====================
    local sec2 = CreateSectionHeader(scrollChild, "Appearance")
    sec2:SetSize(contentWidth, 20)
    sec2:SetPoint("TOPLEFT", 0, nextY(32))

    -- Trail Length slider
    local lengthSlider = CreateModernSlider(scrollChild, "JCT_LengthSlider", "Trail Length",
        5, 50, JarsCursorTrailDB.trailLength, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            JarsCursorTrailDB.trailLength = math.floor(value)
            InitializeTrailFrames()
        end)
    lengthSlider:SetPoint("TOPLEFT", 0, nextY(28))

    -- Fade Duration slider
    local fadeSlider = CreateModernSlider(scrollChild, "JCT_FadeSlider", "Fade Duration",
        0.1, 2.0, JarsCursorTrailDB.fadeTime, 0.1, contentWidth,
        function(v) return string.format("%.1fs", v) end,
        function(value)
            JarsCursorTrailDB.fadeTime = value
        end)
    fadeSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Particle Size slider
    local sizeSlider = CreateModernSlider(scrollChild, "JCT_SizeSlider", "Particle Size",
        16, 64, JarsCursorTrailDB.size, 4, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            JarsCursorTrailDB.size = math.floor(value)
           RefreshTrailParticles()
        end)
    sizeSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Trail Spacing slider
    local spacingSlider = CreateModernSlider(scrollChild, "JCT_SpacingSlider", "Trail Spacing",
        1, 50, JarsCursorTrailDB.spacing, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            JarsCursorTrailDB.spacing = math.floor(value)
        end)
    spacingSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Opacity slider
    local alphaSlider = CreateModernSlider(scrollChild, "JCT_AlphaSlider", "Opacity",
        0.1, 1.0, JarsCursorTrailDB.alpha, 0.1, contentWidth,
        function(v) return string.format("%.1f", v) end,
        function(value)
            JarsCursorTrailDB.alpha = value
            RefreshTrailParticles()
        end)
    alphaSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Texture dropdown
    local textureLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    textureLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    textureLabel:SetTextColor(unpack(UI.text))
    textureLabel:SetPoint("TOPLEFT", 0, nextY(52))
    textureLabel:SetText("Trail Effect")

    local textureDropdown = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    textureDropdown:SetPoint("TOPLEFT", 0, nextY(20))
    textureDropdown:SetWidth(contentWidth)
    textureDropdown:SetDefaultText(JarsCursorTrailDB.texture or "Star")
    textureDropdown:SetupMenu(function(_, rootDescription)
        for name, _ in pairs(textures) do
            rootDescription:CreateRadio(name,
                function() return JarsCursorTrailDB.texture == name end,
                function()
                    JarsCursorTrailDB.texture = name
                    RefreshTrailParticles()
                end)
        end
    end)

    -- =====================
    -- OFFSET SECTION
    -- =====================
    local sec3 = CreateSectionHeader(scrollChild, "Offset")
    sec3:SetSize(contentWidth, 20)
    sec3:SetPoint("TOPLEFT", 0, nextY(42))

    -- X Offset slider
    local offsetXSlider = CreateModernSlider(scrollChild, "JCT_OffsetXSlider", "Horizontal Offset (X)",
        -50, 50, JarsCursorTrailDB.offsetX or 0, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            JarsCursorTrailDB.offsetX = math.floor(value)
        end)
    offsetXSlider:SetPoint("TOPLEFT", 0, nextY(28))

    -- Y Offset slider
    local offsetYSlider = CreateModernSlider(scrollChild, "JCT_OffsetYSlider", "Vertical Offset (Y)",
        -50, 50, JarsCursorTrailDB.offsetY or 0, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            JarsCursorTrailDB.offsetY = math.floor(value)
        end)
    offsetYSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- =====================
    -- COLOR SECTION
    -- =====================
    local sec4 = CreateSectionHeader(scrollChild, "Color")
    sec4:SetSize(contentWidth, 20)
    sec4:SetPoint("TOPLEFT", 0, nextY(52))

    -- Trail Color picker
    local colorLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    colorLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    colorLabel:SetTextColor(unpack(UI.text))
    colorLabel:SetPoint("TOPLEFT", 0, nextY(28))
    colorLabel:SetText("Trail Color")

    local colorButton = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)
    colorButton:SetSize(50, 22)
    colorButton:SetBackdrop(modernBackdrop)
    colorButton:SetBackdropBorderColor(unpack(UI.border))
    local c = JarsCursorTrailDB.color
    colorButton:SetBackdropColor(c.r, c.g, c.b, 1)
    colorButton:SetScript("OnClick", function(self)
        local c = JarsCursorTrailDB.color
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                JarsCursorTrailDB.color = {r = r, g = g, b = b}
                self:SetBackdropColor(r, g, b, 1)
                RefreshTrailParticles()
            end,
            cancelFunc = function(prev)
                JarsCursorTrailDB.color = {r = prev.r, g = prev.g, b = prev.b}
                self:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                RefreshTrailParticles()
            end,
        })
    end)

    -- Rainbow mode checkbox
    local rainbowCheck = CreateModernCheck(scrollChild, "Rainbow/Gradient Mode", JarsCursorTrailDB.rainbowMode, function(val)
        JarsCursorTrailDB.rainbowMode = val
        RefreshTrailParticles()
        -- Enable/disable color button
        if val then
            colorButton:Disable()
            colorButton:SetAlpha(0.5)
            colorLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            colorButton:Enable()
            colorButton:SetAlpha(1)
            colorLabel:SetTextColor(unpack(UI.text))
        end
    end)
    rainbowCheck:SetPoint("TOPLEFT", 0, nextY(30))

    -- Set initial state based on rainbow mode
    if JarsCursorTrailDB.rainbowMode then
        colorButton:Disable()
        colorButton:SetAlpha(0.5)
        colorLabel:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Gradient Type dropdown
    local gradientLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    gradientLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    gradientLabel:SetTextColor(unpack(UI.text))
    gradientLabel:SetPoint("TOPLEFT", 0, nextY(32))
    gradientLabel:SetText("Gradient Type")

    local gradientDropdown = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    gradientDropdown:SetPoint("TOPLEFT", 0, nextY(20))
    gradientDropdown:SetWidth(contentWidth)
    gradientDropdown:SetDefaultText(JarsCursorTrailDB.gradientType or "Fire")

    -- Custom Colors section
    local customColorsLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    customColorsLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    customColorsLabel:SetTextColor(unpack(UI.text))
    customColorsLabel:SetPoint("TOPLEFT", 0, nextY(32))
    customColorsLabel:SetText("Custom Gradient Colors")

    -- Custom Color 1-3 buttons
    local customColorY = nextY(24)
    local customColor1Button = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    customColor1Button:SetSize(60, 25)
    customColor1Button:SetPoint("TOPLEFT", 0, customColorY)
    customColor1Button:SetBackdrop(modernBackdrop)
    customColor1Button:SetBackdropBorderColor(unpack(UI.border))
    customColor1Button:SetBackdropColor(JarsCursorTrailDB.customColor1.r, JarsCursorTrailDB.customColor1.g, JarsCursorTrailDB.customColor1.b, 1)
    customColor1Button:SetScript("OnClick", function(self)
        local c = JarsCursorTrailDB.customColor1
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                JarsCursorTrailDB.customColor1 = {r = r, g = g, b = b}
                self:SetBackdropColor(r, g, b, 1)
                RefreshTrailParticles()
            end,
            cancelFunc = function(prev)
                JarsCursorTrailDB.customColor1 = {r = prev.r, g = prev.g, b = prev.b}
                self:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                RefreshTrailParticles()
            end,
        })
    end)

    local customColor2Button = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    customColor2Button:SetSize(60, 25)
    customColor2Button:SetPoint("LEFT", customColor1Button, "RIGHT", 10, 0)
    customColor2Button:SetBackdrop(modernBackdrop)
    customColor2Button:SetBackdropBorderColor(unpack(UI.border))
    customColor2Button:SetBackdropColor(JarsCursorTrailDB.customColor2.r, JarsCursorTrailDB.customColor2.g, JarsCursorTrailDB.customColor2.b, 1)
    customColor2Button:SetScript("OnClick", function(self)
        local c = JarsCursorTrailDB.customColor2
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                JarsCursorTrailDB.customColor2 = {r = r, g = g, b = b}
                self:SetBackdropColor(r, g, b, 1)
                RefreshTrailParticles()
            end,
            cancelFunc = function(prev)
                JarsCursorTrailDB.customColor2 = {r = prev.r, g = prev.g, b = prev.b}
                self:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                RefreshTrailParticles()
            end,
        })
    end)

    local customColor3Button = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    customColor3Button:SetSize(60, 25)
    customColor3Button:SetPoint("LEFT", customColor2Button, "RIGHT", 10, 0)
    customColor3Button:SetBackdrop(modernBackdrop)
    customColor3Button:SetBackdropBorderColor(unpack(UI.border))
    customColor3Button:SetBackdropColor(JarsCursorTrailDB.customColor3.r, JarsCursorTrailDB.customColor3.g, JarsCursorTrailDB.customColor3.b, 1)
    customColor3Button:SetScript("OnClick", function(self)
        local c = JarsCursorTrailDB.customColor3
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                JarsCursorTrailDB.customColor3 = {r = r, g = g, b = b}
                self:SetBackdropColor(r, g, b, 1)
                RefreshTrailParticles()
            end,
            cancelFunc = function(prev)
                JarsCursorTrailDB.customColor3 = {r = prev.r, g = prev.g, b = prev.b}
                self:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                RefreshTrailParticles()
            end,
        })
    end)

    -- Initially hide custom colors if not in Custom mode
    local showCustom = (JarsCursorTrailDB.gradientType == "Custom")
    customColorsLabel:SetShown(showCustom)
    customColor1Button:SetShown(showCustom)
    customColor2Button:SetShown(showCustom)
    customColor3Button:SetShown(showCustom)

    -- Gradient dropdown setup (defined after custom color buttons exist)
    gradientDropdown:SetupMenu(function(_, rootDescription)
        local gradientNames = {"Fire", "Ice", "Toxic", "Arcane", "Custom"}
        for _, name in ipairs(gradientNames) do
            rootDescription:CreateRadio(name,
                function() return JarsCursorTrailDB.gradientType == name end,
                function()
                    JarsCursorTrailDB.gradientType = name
                    local showCustom = (name == "Custom")
                    customColorsLabel:SetShown(showCustom)
                    customColor1Button:SetShown(showCustom)
                    customColor2Button:SetShown(showCustom)
                    customColor3Button:SetShown(showCustom)
                    RefreshTrailParticles()
                end)
        end
    end)

    -- =====================
    -- ACTIONS SECTION
    -- =====================
    local sec5 = CreateSectionHeader(scrollChild, "Actions")
    sec5:SetSize(contentWidth, 20)
    sec5:SetPoint("TOPLEFT", 0, nextY(36))

    local resetBtn = CreateModernButton(scrollChild, "Reset to Default", 160, 30, function()
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
        JarsCursorTrailDB.customColor1 = {r = 1, g = 0, b = 0}
        JarsCursorTrailDB.customColor2 = {r = 1, g = 1, b = 0}
        JarsCursorTrailDB.customColor3 = {r = 0, g = 0, b = 1}
        
        InitializeTrailFrames()
        RefreshTrailParticles()
        print("JarsCursorTrail: Settings reset to defaults")
        
        -- Close and reopen to refresh UI
        configFrame:Hide()
        configFrame = nil
        CreateConfigWindow():Show()
    end)
    resetBtn:SetPoint("TOPLEFT", 0, nextY(28))

    -- Set scroll child height
    scrollChild:SetHeight(math.abs(yOff) + 20)
    
    return configFrame
end

-- Initialize addon
local function Initialize()
    -- Initialize trail frames
    InitializeTrailFrames()
    
    -- Create update frame
    updateFrame = CreateFrame("Frame")
    local trailTimer = 0
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        trailTimer = trailTimer + elapsed
        if trailTimer >= JarsCursorTrailDB.updateInterval then
            trailTimer = 0
            UpdateTrail()
        end
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
