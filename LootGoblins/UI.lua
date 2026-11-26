local _, A = ...
local function text(parent,size)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    t:SetFont(STANDARD_TEXT_FONT,size or 12,""); t:SetJustifyH("LEFT")
    return t
end
local function panel(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetBackdrop({bgFile="Interface\\FrameGeneral\\UI-Background-Rock",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}})
    f:SetBackdropColor(0.12,0.11,0.09,0.97); f:SetBackdropBorderColor(1,1,1,1)
    return f
end
local function button(parent,label,w,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w or 80,22); b:SetText(label); b:SetScript("OnClick",callback)
    return b
end
local function tooltip(widget,fn)
    widget:EnableMouse(true)
    widget:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); fn(self); GameTooltip:Show()
    end)
    widget:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function movable(f,save)
    f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) if not A.db.locked then self.dragging=true; self:StartMoving() end end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing(); self.dragging=false
        if save then
            local x,y=self:GetCenter(); local px,py=UIParent:GetCenter()
            local ratio=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
            A.db.x=x*ratio-px; A.db.y=y*ratio-py
            -- Anchor uses UIParent-relative pixels at the child's scale.
            A.db.x=A.db.x/A.db.scale; A.db.y=A.db.y/A.db.scale
        end
    end)
end
function A.BuildSettings(parent)
    if A.settings then return A.settings end
    local f=parent or panel(UIParent); A.settings=f
    if not parent then
        f:SetSize(480,640); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); movable(f,false)
    end
    local title=text(f,16); title:SetPoint("TOPLEFT",18,-18); title:SetText("LootGoblins settings")
    if not parent then local close=button(f,"Close",65,function() f:Hide() end); close:SetPoint("TOPRIGHT",-14,-14) end
    local common=CreateFrame("Frame",nil,f); common:SetAllPoints(); local advanced=CreateFrame("Frame",nil,f); advanced:SetAllPoints(); advanced:Hide()
    local toggle=button(f,"Advanced",100,function()
        local show=not advanced:IsShown(); common:SetShown(not show); advanced:SetShown(show)
    end); toggle:SetPoint("TOPLEFT",18,-51)
    local basic=button(f,"Common",90,function() common:Show(); advanced:Hide() end); basic:SetPoint("LEFT",toggle,"RIGHT",8,0)
    local function label(parent,title,y)
        local t=text(parent,12); t:SetPoint("TOPLEFT",20,-y); t:SetText(title); return t
    end
    local function check(parent,key,title,y)
        local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); b:SetPoint("TOPLEFT",16,-y); b:SetSize(28,28)
        local t=text(parent,12); t:SetPoint("LEFT",b,"RIGHT",5,0); t:SetText(title)
        A.settingsChecks=A.settingsChecks or {}; A.settingsChecks[key]=b
        b:SetScript("OnShow",function() b:SetChecked(A.db[key]) end)
        b:SetChecked(A.db[key]); b:SetScript("OnClick",function()
            if key=="betsEnabled" and A.betClient then A.betClient:SetEnabled(not not b:GetChecked())
            else A.db[key]=not not b:GetChecked() end
            if key=="tooltipAuctionator" or key=="tooltipGearQuest" then A.RefreshTooltipSettings() end
            if A.ApplyNative then A.ApplyNative() end; A.Render()
        end)
    end
    local function number(parent,key,title,y,min,max)
        label(parent,title,y+5)
        local box=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); box:SetSize(76,25); box:SetPoint("TOPRIGHT",-22,-y)
        box:SetAutoFocus(false); box:SetMaxLetters(8); box:SetText(tostring(A.db[key]))
        local function commit()
            local v=tonumber(box:GetText())
            if v and v==v then A.db[key]=math.max(min,math.min(max,v)) end
            if key=="archiveLimit" then A.PruneArchive(A.db) end
            box:SetText(tostring(A.db[key])); A.Render()
        end
        box:SetScript("OnEnterPressed",function() commit(); box:ClearFocus() end)
        box:SetScript("OnEditFocusLost",commit)
    end
    label(common,"One loot queue · icon tabs · automatic next item",105)
    number(common,"closeAfter","Close result after seconds (0 = keep)",147,0,300)
    number(common,"scale","UI scale (0.65–1.6)",190,0.65,1.6)
    check(common,"pauseHover","Pause closing while hovered",235)
    check(common,"locked","Lock window position",275)
    local modes={queue="LootGoblins loot queue",none="Blizzard UI only"}
    local mode=button(common,modes[A.db.presentation],240,function(self)
        A.db.presentation=A.db.presentation=="queue" and "none" or "queue"
        self:SetText(modes[A.db.presentation]); A.ApplyNative(); A.Render()
    end); mode:SetPoint("TOPLEFT",20,-315)
    mode:SetScript("OnShow",function(self) self:SetText(modes[A.db.presentation]) end)
    check(common,"showPassed","Show players who passed",352)
    local preview=button(common,"Preview rolls",125,function() A.Demo() end); preview:SetPoint("TOPLEFT",20,-400)
    local history=button(common,"History / stats",125,function() A.OpenHistory("players") end); history:SetPoint("LEFT",preview,"RIGHT",10,0)
    check(common,"betsEnabled","Enable side bets (hide choices until resolution)",438)
    local bets=button(common,"Side bets / ledger",160,function() A.OpenBets() end); bets:SetPoint("TOPLEFT",20,-478)
    label(common,"Tooltip addons",520)
    check(common,"tooltipAuctionator","Auctionator prices in item details",545)
    check(common,"tooltipGearQuest","GearQuest rankings and notes in item details",580)
    label(advanced,"Loot window width adapts to the item and betting setting",105)
    number(advanced,"rowHeight","Player row height",142,18,32)
    number(advanced,"fontSize","Player font size",184,10,18)
    number(advanced,"opacity","Panel opacity (0.4–1)",226,0.4,1)
    number(advanced,"maxHeight","Maximum player table height",268,300,900)
    number(advanced,"historyLimit","Completed items kept this session",310,10,200)
    check(advanced,"showPassed","Show players who passed",353)
    check(advanced,"classColors","Use class colors for player names",390)
    check(advanced,"sound","Play a sound on confirmed results",427)
    check(advanced,"groupSeparators","Separate Need / Greed / Pass groups",464)
    local sort=button(advanced,"Toggle player sorting",180,function()
        A.db.sort=A.db.sort=="name" and "priority" or "name"; A.Render()
        print("LootGoblins: within each choice group, sort by "..(A.db.sort=="name" and "name" or "roll"))
    end); sort:SetPoint("TOPLEFT",20,-506)
    local reset=button(advanced,"Reset position",130,function() A.db.x=0; A.db.y=180; A.db.lootPositions={}; A.Render() end); reset:SetPoint("TOPLEFT",20,-545)
    number(advanced,"archiveLimit","Persistent history: maximum drops",585,100,50000)
    return f
end

function A.RegisterSettings()
    local f=CreateFrame("Frame", "LootGoblinsSettingsPanel", UIParent); f.name="LootGoblins"; f:Hide()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        A.settingsCategory=Settings.RegisterCanvasLayoutCategory(f,"LootGoblins")
        Settings.RegisterAddOnCategory(A.settingsCategory)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",0,-8); scroll:SetPoint("BOTTOMRIGHT",-30,8)
        local content=CreateFrame("Frame",nil,scroll); content:SetSize(480,640)
        scroll:SetScrollChild(content); A.BuildSettings(content)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(f); A.legacySettings=f; A.BuildSettings(f)
    end
end
function A.OpenSettings()
    if A.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(A.settingsCategory:GetID())
    elseif A.legacySettings and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(A.legacySettings)
    else
        A.BuildSettings():Show()
    end
end
