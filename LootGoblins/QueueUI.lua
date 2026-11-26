local _,A=...
local WHITE="Interface\\Buttons\\WHITE8X8"
local actions={{kind=1,name=NEED or "Need",icon="Interface\\Buttons\\UI-GroupLoot-Dice-Up"},
    {kind=2,name=GREED or "Greed",icon="Interface\\Buttons\\UI-GroupLoot-Coin-Up"},
    {kind=0,name=PASS or "Pass",icon="Interface\\Buttons\\UI-GroupLoot-Pass-Up"},
    {kind=3,name=ROLL_DISENCHANT or "Disenchant",icon="Interface\\Buttons\\UI-GroupLoot-DE-Up"},
    {kind=4,name=TRANSMOGRIFY or "Transmog",icon="Interface\\Icons\\INV_Enchant_Disenchant"}}
local function label(parent,size)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    t:SetFont(STANDARD_TEXT_FONT,size or 11,""); t:SetJustifyH("LEFT"); return t
end
local function fill(parent,r,g,b,a,layer)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND"); t:SetColorTexture(r,g,b,a); return t
end
local function skin(f)
    f:SetBackdrop({bgFile=WHITE,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(0.09,0.105,0.09,1); f:SetBackdropBorderColor(0.35,0.39,0.29,1)
end
local function refreshItemTooltip(tip,elapsed)
    local pending=tip.shouldRefreshData
    -- Delegate data refresh, ownership and timing to the client's own updater.
    GameTooltip_OnUpdate(tip,elapsed)
    if pending and not tip.shouldRefreshData then
        -- A crafted item may finish loading independently of its pattern.
        A.itemSizeRevision=(A.itemSizeRevision or 0)+1
    end
end
local function prepareItemTooltip(tip)
    tip.gqSkipScoreHook=not A.db.tooltipGearQuest
    tip:SetScript("OnUpdate",refreshItemTooltip)
    if GameTooltip_OnShow then tip:HookScript("OnShow",GameTooltip_OnShow) end
    tip:HookScript("OnTooltipCleared",function(self)
        self.gqSkipScoreHook=not A.db.tooltipGearQuest
        self.gqScoreLineAdded=nil; self.gqEnchantAdded=nil
        if self.ItemTooltip then self.ItemTooltip:Hide() end
    end)
end
local function itemTooltip(name,parent)
    local tip=CreateFrame("GameTooltip",name,parent,"GameTooltipTemplate")
    -- GameTooltipTemplate alone omits the embedded item region that Blizzard
    -- adds to its standard GameTooltip. Supply it on both of our tooltips.
    local embedded=CreateFrame("Frame",name.."EmbeddedItem",tip,"InternalEmbeddedItemTooltipTemplate")
    embedded:SetPoint("BOTTOMLEFT",tip,"BOTTOMLEFT",10,13); embedded.yspacing=13
    embedded:Hide(); tip.ItemTooltip=embedded
    -- GearQuestForever's item postprocessor runs on custom tooltips too, but its
    -- clear hooks only cover GameTooltip/ItemRefTooltip. Match that cleanup on
    -- our own frames so its duplicate-line guards cannot suppress a new item.
    prepareItemTooltip(tip)
    if embedded.Tooltip then prepareItemTooltip(embedded.Tooltip) end
    return tip
end
local function populateItemTooltip(tip,owner,link)
    -- Use identical population order for measurement and the visible details,
    -- including the tooltip processors installed by other addons.
    tip:Hide(); tip:SetOwner(owner,"ANCHOR_NONE"); tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT",owner,"TOPLEFT",0,0); tip:SetHyperlink(link); tip:Show()
    if GameTooltip_CalculatePadding then GameTooltip_CalculatePadding(tip) end
end
function A.RefreshTooltipSettings()
    local f=A.lootWindow; if not f or not f.details then return end
    local key=tostring(A.db.tooltipAuctionator)..":"..tostring(A.db.tooltipGearQuest)
    if f.tooltipSettingsKey==key then return end
    if f.itemTooltip then f.itemTooltip:Hide(); f.measureTooltip:Hide() end
    f.tooltipPairs=f.tooltipPairs or {}
    local provider=A.db.tooltipAuctionator and "pricing" or "native"
    local pair=f.tooltipPairs[provider]
    if not pair then
        -- Auctionator opts custom tooltips in by name. Separate native pairs
        -- opt out without changing Auctionator or its settings globally.
        local prefix=A.db.tooltipAuctionator and "NotGameTooltipLootGoblins" or "LootGoblinsNative"
        pair={item=itemTooltip(prefix.."ItemTooltip",f.details),measure=itemTooltip(prefix.."MeasureTooltip",f)}
        pair.measure:SetAlpha(0); pair.measure:EnableMouse(false); pair.measure:Hide()
        f.tooltipPairs[provider]=pair
    end
    f.itemTooltip=pair.item; f.measureTooltip=pair.measure
    for _,tip in ipairs({pair.item,pair.measure}) do
        tip.gqSkipScoreHook=not A.db.tooltipGearQuest; tip.queueLink=nil
        if tip.ItemTooltip and tip.ItemTooltip.Tooltip then tip.ItemTooltip.Tooltip.gqSkipScoreHook=not A.db.tooltipGearQuest end
    end
    f.tooltipSettingsKey=key; f.queueSize=nil
    A.itemSizeRevision=(A.itemSizeRevision or 0)+1
end
local function hover(b,fn)
    b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); fn(self); GameTooltip:Show() end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function iconButton(parent,texture,name,fn)
    local b=CreateFrame("Button",nil,parent); b:SetSize(28,28)
    b.image=b:CreateTexture(nil,"ARTWORK"); b.image:SetPoint("TOPLEFT",3,-3); b.image:SetPoint("BOTTOMRIGHT",-3,3)
    b.image:SetTexture(texture); b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    b:SetScript("OnClick",fn); hover(b,function() GameTooltip:SetText(name) end); return b
end
local function drag(widget,window)
    widget:EnableMouse(true); widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnDragStart",function() if not A.db.locked then window.dragging=true; window:StartMoving() end end)
    widget:SetScript("OnDragStop",function()
        window:StopMovingOrSizing(); window.dragging=false
        local x,y=window:GetCenter(); local px,py=UIParent:GetCenter()
        local ratio=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
        A.db.x=(x*ratio-px)/A.db.scale; A.db.y=(y*ratio-py)/A.db.scale
        if window.minimized then A.db.y=A.db.y-((window.minimizedHeight or window.expandedHeight)-34)/2 end
    end)
end
local function visibleRolls()
    local result={}
    for _,r in ipairs(A.rolls) do if not r.dismissed and not r.queueHidden then result[#result+1]=r end end
    return result
end
local function undecided(r)
    return not r.finished and not r.closed and r.choice==nil and GetTime()<r.started+r.duration
end
function A.CanCloseQueue()
    for _,r in ipairs(visibleRolls()) do if undecided(r) then return false end end
    return true
end
function A.CloseQueue()
    if not A.CanCloseQueue() then return false end
    -- Closing is presentation-only: live history and pledged bets keep running.
    for _,r in ipairs(visibleRolls()) do r.queueHidden=true end
    A.Render(); return true
end
function A.ToggleQueueMinimized()
    local f=A.lootWindow; if not f then return end
    if f.minimized then
        A.db.y=A.db.y+((f.minimizedHeight or f.expandedHeight)-f.expandedHeight)/2
        f.minimizedHeight=nil
    else f.minimizedHeight=f.expandedHeight or f:GetHeight() end
    f.minimized=not f.minimized; A.Render()
end
local function nextChoice(rolls,selected)
    local index=1
    for i,r in ipairs(rolls) do if r==selected then index=i; break end end
    for step=1,#rolls do
        local r=rolls[(index+step-1)%#rolls+1]
        if undecided(r) then return r end
    end
end
function A.QueueScroll(delta)
    local f=A.lootWindow; if not f then return end
    local max=math.max(0,f.tabExtent-f.tabViewport:GetWidth())
    f.tabOffset=math.max(0,math.min(max,(f.tabOffset or 0)+delta))
    f.tabViewport:SetHorizontalScroll(f.tabOffset)
    f.previous:SetEnabled(f.tabOffset>0); f.next:SetEnabled(f.tabOffset<max)
end
function A.EnsureQueueTab(index)
    local f=A.lootWindow; local left=(index-1)*48; local right=left+46
    local offset=f.tabOffset or 0; local width=f.tabViewport:GetWidth()
    if left<offset then A.QueueScroll(left-offset)
    elseif right>offset+width then A.QueueScroll(right-offset-width) end
end
function A.BuildUI()
    local f=CreateFrame("Frame","LootGoblinsLootQueue",UIParent,"BackdropTemplate"); A.lootWindow=f
    skin(f); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:SetClampedToScreen(true); drag(f,f)
    f:SetSize(510,310); f:SetPoint("CENTER",UIParent,"CENTER",A.db.x,A.db.y)
    f.header=CreateFrame("Frame",nil,f); f.header:SetPoint("TOPLEFT",5,-4); f.header:SetPoint("TOPRIGHT",-5,-4); f.header:SetHeight(26); drag(f.header,f)
    f.title=label(f.header,12); f.title:SetPoint("LEFT",7,0); f.title:SetText("|cffb5d982LootGoblins|r")
    f.count=label(f.header,10); f.count:SetPoint("RIGHT",-112,0); f.count:SetJustifyH("RIGHT")
    f.close=CreateFrame("Button",nil,f.header,"UIPanelCloseButton"); f.close:SetSize(24,24); f.close:SetPoint("RIGHT",-1,0)
    f.close:SetScript("OnClick",function() A.CloseQueue() end)
    if f.close.SetMotionScriptsWhileDisabled then f.close:SetMotionScriptsWhileDisabled(true) end
    hover(f.close,function()
        GameTooltip:SetText(A.CanCloseQueue() and "Close loot pane" or "Choose all available loot rolls before closing")
    end)
    f.minimize=CreateFrame("Button",nil,f.header,"UIPanelButtonTemplate"); f.minimize:SetSize(22,20)
    f.minimize:SetPoint("RIGHT",f.close,"LEFT",-1,0); f.minimize:SetText("-")
    f.minimize:SetScript("OnClick",function() A.ToggleQueueMinimized() end)
    hover(f.minimize,function() GameTooltip:SetText(f.minimized and "Restore loot pane" or "Minimize to header") end)
    f.settings=iconButton(f.header,"Interface\\Buttons\\UI-OptionsButton","Settings",function() A.OpenSettings() end)
    f.settings:SetSize(24,24); f.settings:SetPoint("RIGHT",f.minimize,"LEFT",-3,0)
    f.history=iconButton(f.header,"Interface\\Icons\\INV_Misc_Book_09","Loot history",function() A.OpenHistory("drops") end)
    f.history:SetSize(24,24); f.history:SetPoint("RIGHT",f.settings,"LEFT",-3,0)
    f.lootrow=CreateFrame("Frame",nil,f); f.lootrow:SetPoint("TOPLEFT",5,-31); f.lootrow:SetPoint("TOPRIGHT",-5,-31); f.lootrow:SetHeight(52)
    local background=fill(f.lootrow,0.14,0.16,0.13,1); background:SetAllPoints()
    f.baseline=fill(f.lootrow,0.35,0.39,0.29,1,"BORDER"); f.baseline:SetHeight(1); f.baseline:SetPoint("BOTTOMLEFT"); f.baseline:SetPoint("BOTTOMRIGHT")
    f.tabViewport=CreateFrame("ScrollFrame",nil,f.lootrow); f.tabViewport:SetPoint("TOPLEFT",6,0); f.tabViewport:SetHeight(53)
    f.tabContent=CreateFrame("Frame",nil,f.tabViewport); f.tabContent:SetSize(1,53); f.tabViewport:SetScrollChild(f.tabContent)
    f.tabViewport:EnableMouseWheel(true); f.tabViewport:SetScript("OnMouseWheel",function(_,d) A.QueueScroll(-d*48) end)
    f.tabButtons={}; f.tabOffset=0; f.tabExtent=0
    -- The actions occupy their own non-scrolling space above the tab content.
    f.actions=CreateFrame("Frame",nil,f.lootrow); f.actions:SetHeight(48); f.actions:SetPoint("RIGHT",-5,0)
    f.actions:SetFrameLevel(f.tabViewport:GetFrameLevel()+10)
    local actionBackground=fill(f.actions,0.14,0.16,0.13,1); actionBackground:SetAllPoints()
    f.buttons={}
    for _,action in ipairs(actions) do
        local kind=action.kind
        local b=iconButton(f.actions,action.icon,action.name,function() if f.roll then A.Choose(f.roll,kind) end end)
        hover(b,function(self)
            GameTooltip:SetText(action.name)
            if self.reason then GameTooltip:AddLine(self.reason,1,0.4,0.4,true) end
            if f.roll and f.roll.choice~=nil then GameTooltip:AddLine("Your choice: "..({[0]="Pass",[1]="Need",[2]="Greed",[3]="Disenchant",[4]="Transmog"})[f.roll.choice],0.7,0.85,0.6) end
        end)
        f.buttons[kind]=b
    end
    f.previous=iconButton(f.lootrow,"Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up","Previous items",function() A.QueueScroll(-144) end)
    f.next=iconButton(f.lootrow,"Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up","Next items",function() A.QueueScroll(144) end)
    f.previous:SetSize(18,24); f.next:SetSize(18,24)
    f.previous:SetFrameLevel(f.actions:GetFrameLevel()); f.next:SetFrameLevel(f.actions:GetFrameLevel())
    f.details=CreateFrame("Frame",nil,f); f.details:SetPoint("TOPLEFT",8,-89)
    -- A dedicated GameTooltip renders every client-supplied item line, including
    -- random enchants, sockets and set effects; the hover tooltip stays separate.
    A.RefreshTooltipSettings()
    f.measureName=label(f); f.measureName:Hide()
    f.fallbackText=label(f.details,12); f.fallbackText:SetPoint("TOPLEFT",8,-4); f.fallbackText:SetWidth(240); f.fallbackText:SetJustifyV("TOP")
    f.table=CreateFrame("Frame",nil,f); f.table:SetPoint("TOPRIGHT",-10,-89)
    f.divider=fill(f,0.3,0.34,0.27,1,"BORDER"); f.divider:SetWidth(1)
    f.playerHeading=label(f.table,10); f.playerHeading:SetPoint("TOPLEFT",1,-2); f.playerHeading:SetText("PLAYER")
    f.rollHeading=label(f.table,10); f.rollHeading:SetJustifyH("RIGHT")
    f.betHeading=label(f.table,10); f.betHeading:SetPoint("TOPRIGHT",-2,-2); f.betHeading:SetText("BET")
    f.playerScroll=CreateFrame("ScrollFrame",nil,f.table,"UIPanelScrollFrameTemplate")
    f.playerScroll:SetPoint("TOPLEFT",0,-23)
    f.playerContent=CreateFrame("Frame",nil,f.playerScroll); f.playerContent:SetSize(200,1); f.playerScroll:SetScrollChild(f.playerContent)
    f.rows={}
    f:Hide(); A.Render()
end
local function makeTab(f,index)
    local b=CreateFrame("Button",nil,f.tabContent,"BackdropTemplate"); skin(b); b:SetSize(46,52)
    b:SetPoint("TOPLEFT",(index-1)*48,0)
    b.image=b:CreateTexture(nil,"ARTWORK"); b.image:SetSize(34,34); b.image:SetPoint("TOP",0,-8)
    b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate"); b.cooldown:SetAllPoints(b.image)
    if b.cooldown.SetDrawEdge then b.cooldown:SetDrawEdge(false) end
    if b.cooldown.SetDrawBling then b.cooldown:SetDrawBling(false) end
    if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
    b.time=label(b,10); b.time:SetPoint("BOTTOMRIGHT",-1,1); b.time:SetJustifyH("RIGHT")
    b.chosen=b:CreateTexture(nil,"OVERLAY"); b.chosen:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); b.chosen:SetSize(13,13); b.chosen:SetPoint("TOPRIGHT",0,-1)
    b.join=CreateFrame("Frame",nil,b); b.join:SetFrameLevel(b.cooldown:GetFrameLevel()+2)
    b.join:SetPoint("BOTTOMLEFT",3,-1); b.join:SetPoint("BOTTOMRIGHT",-3,-1); b.join:SetHeight(5)
    local join=fill(b.join,0.09,0.105,0.09,1); join:SetAllPoints()
    b.result=fill(b,0.2,1,0.3,0.18,"OVERLAY"); b.result:SetAllPoints(b.image)
    b:SetScript("OnClick",function() A.selected=b.roll; A.queueReveal=true; A.Render() end)
    hover(b,function()
        if b.roll.link then GameTooltip:SetHyperlink(b.roll.link) else GameTooltip:SetText(b.roll.name or "Item") end
        if b.roll.resultConfirmed then GameTooltip:AddLine(b.roll.status,0.7,0.85,0.6) end
    end)
    f.tabButtons[index]=b; return b
end
local function tooltipSize(tip,f)
    -- GameTooltip can ignore parent scale. Convert its local dimensions into
    -- queue units instead of enlarging that already-scaled space a second time.
    if GameTooltip_CalculatePadding then GameTooltip_CalculatePadding(tip) end
    local ratio=tip:GetEffectiveScale()/f:GetEffectiveScale()
    return tip:GetWidth()*ratio+4,tip:GetHeight()*ratio
end
local function itemDetails(f,r)
    local tip=f.itemTooltip
    if r.link then
        f.fallbackText:Hide()
        if tip.queueRoll~=r or tip.queueLink~=r.link or not tip:IsShown() then
            populateItemTooltip(tip,f.details,r.link)
            tip.queueRoll=r; tip.queueLink=r.link
            if tip.SetBackdropColor then tip:SetBackdropColor(0.09,0.105,0.09,0) end
            if tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(0,0,0,0) end
        end
        return tooltipSize(tip,f)
    end
    tip:Hide(); f.fallbackText:Show()
    f.fallbackText:SetText((r.name or "Loading item…").."\n\nWaiting for item information")
    local height=f.fallbackText:GetStringHeight(); f.fallbackText:SetHeight(height)
    return f.fallbackText:GetWidth()+16,height+8
end
local function makeRow(f,index)
    local row=CreateFrame("Frame",nil,f.playerContent); row:SetHeight(25)
    row.winner=fill(row,0.33,0.58,0.2,0.3); row.winner:SetAllPoints()
    row.separator=fill(row,0.3,0.34,0.27,1,"BORDER"); row.separator:SetHeight(1); row.separator:SetPoint("TOPLEFT",0,3); row.separator:SetPoint("TOPRIGHT",0,3)
    row.name=label(row); row.name:SetPoint("TOPLEFT",1,-5); row.name:SetHeight(15)
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.choice=row:CreateTexture(nil,"ARTWORK"); row.choice:SetSize(15,15)
    row.value=label(row); row.value:SetJustifyH("RIGHT")
    row.stake=label(row,10); row.stake:SetPoint("TOPLEFT",1,-22); row.stake:SetTextColor(0.9,0.77,0.45)
    row.bets={}
    for slot,amount in ipairs({1,100,10000}) do
        local b=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); b:SetSize(27,22)
        b:SetNormalFontObject("GameFontHighlightSmall"); b:SetText(({"1c","1s","1g"})[slot])
        b:SetScript("OnClick",function() if row.player then A.PlaceInlineBet(f.roll,row.player,amount) end end)
        hover(b,function()
            GameTooltip:SetText("Add "..A.BetModel.Money(amount).." on "..(row.player and row.player.playerName or "player"))
            if f.roll.inlineBetError then GameTooltip:AddLine(f.roll.inlineBetError,1,0.4,0.4,true)
            elseif row.reason then GameTooltip:AddLine(A.BetModel.reasons[row.reason] or row.reason,0.85,0.8,0.6,true) end
        end)
        row.bets[slot]=b
    end
    hover(row,function()
        local p=row.player; if not p then return end
        GameTooltip:SetText(p.playerName or "Player")
        if A.HideChoices(f.roll,A.db) then GameTooltip:AddLine("Choices and rolls hidden until loot resolution",0.8,0.8,0.7,true)
        else GameTooltip:AddLine((A.labels[p.state] or "Waiting").." · "..tostring(p.roll or "—")) end
        if row.amount then GameTooltip:AddLine("Your stake: "..A.BetModel.Money(row.amount),1,0.82,0.3) end
        if f.roll.resultConfirmed and p.isWinner then GameTooltip:AddLine("Loot winner",0.5,1,0.4) end
    end)
    f.rows[index]=row; return row
end
-- Measure every queued item before drawing any tab. Keep the largest pane sizes
-- until the queue empties, including after the largest item has been dismissed.
local function queueMetrics(f,rolls)
    local size=f.queueSize
    local parentScale=f:GetEffectiveScale()
    if size and size.parentScale~=parentScale then size=nil end
    if size then
        local overlap=false
        for _,r in ipairs(rolls) do if size.members[r] then overlap=true; break end end
        if not overlap then size=nil end
    end
    size=size or {detailWidth=0,detailHeight=0,nameWidth=68,heights={},members={},parentScale=parentScale}
    f.queueSize=size
    local betting=not not A.db.betsEnabled
    local height=size.heights[betting] or 0
    f.measureName:SetFont(STANDARD_TEXT_FONT,A.db.fontSize,"")
    for _,r in ipairs(rolls) do
        size.members[r]=true
        local cached=r.queueItemSize
        if r.link and (not cached or cached.link~=r.link or cached.revision~=(A.itemSizeRevision or 0) or cached.parentScale~=parentScale) then
            local tip=f.measureTooltip
            populateItemTooltip(tip,f.details,r.link)
            local width,height=tooltipSize(tip,f)
            cached={link=r.link,revision=A.itemSizeRevision or 0,width=width,height=height,parentScale=parentScale}
            r.queueItemSize=cached; tip:Hide()
        end
        if cached then
            size.detailWidth=math.max(size.detailWidth,cached.width)
            size.detailHeight=math.max(size.detailHeight,cached.height)
        end
        local rows=A.SortedRows(r,A.db)
        for _,p in ipairs(rows) do
            f.measureName:SetText(p.playerName or "Unknown")
            size.nameWidth=math.max(size.nameWidth,math.min(112,f.measureName:GetStringWidth()+8))
        end
        local inline=A.InlineBetState(r)
        local hidden=A.HideChoices(r,A.db)
        local y=0; local previousGroup
        for _,p in ipairs(rows) do
            local group=A.RollGroup(p.state)
            if not hidden and A.db.groupSeparators and previousGroup and group~=previousGroup then y=y+6 end
            previousGroup=group
            local stake=inline.visible and inline.mine and inline.mine.targets[p.playerGUID]
            y=y+math.max(25,A.db.rowHeight+6)+(stake and 14 or 0)
        end
        local cap=math.min(260,math.max(100,A.db.maxHeight-100))
        height=math.max(height,math.min(cap,math.max(25,y))+24)
    end
    size.heights[betting]=height
    return size,height
end
local function partyTable(f,r,betting,minNameWidth)
    local db=A.db; local hidden=A.HideChoices(r,db); local rows=A.SortedRows(r,db)
    local nameWidth=minNameWidth or 68
    for i,p in ipairs(rows) do
        local row=f.rows[i] or makeRow(f,i); row.name:SetText(p.playerName or "Unknown")
        nameWidth=math.max(nameWidth,math.min(112,row.name:GetStringWidth()+8))
    end
    local betWidth=betting.visible and 88 or 0
    local rowWidth=nameWidth+59+betWidth
    local y=0; local previousGroup
    for i,p in ipairs(rows) do
        local group=A.RollGroup(p.state)
        local boundary=not hidden and db.groupSeparators and previousGroup and group~=previousGroup
        if boundary then y=y+6 end; previousGroup=group
        local row=f.rows[i]; row.separator:SetShown(not not boundary); row.player=p; row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y)
        row:SetWidth(rowWidth); row.name:SetWidth(nameWidth)
        local class=db.classColors and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.playerClass]
        row.name:SetTextColor(class and class.r or 0.9,class and class.g or 0.9,class and class.b or 0.85)
        row.name:SetFont(STANDARD_TEXT_FONT,db.fontSize,""); row.value:SetFont(STANDARD_TEXT_FONT,db.fontSize,"")
        row.choice:ClearAllPoints(); row.choice:SetPoint("TOPLEFT",nameWidth+1,-5)
        local kind=({[0]=1,[1]=1,[2]=4,[3]=2,[5]=0})[p.state]
        local ownChoice; if p.isSelf then ownChoice=r.choice end
        if hidden then kind=ownChoice end
        local texture
        for _,a in ipairs(actions) do if a.kind==kind then texture=a.icon end end
        row.choice:SetShown(texture~=nil); if texture then row.choice:SetTexture(texture) end
        row.value:ClearAllPoints(); row.value:SetPoint("TOPRIGHT",-betWidth-2,-5); row.value:SetWidth(hidden and 51 or 31)
        row.value:SetText(hidden and (ownChoice~=nil and "" or "Hidden") or tostring(p.roll or "—"))
        row.value:SetTextColor(0.8,0.83,0.76)
        local target=p.playerGUID
        local amount=betting.visible and betting.mine and betting.mine.targets[target]
        row.amount=amount; row.stake:SetShown(not not amount)
        if amount then row.stake:SetText(A.BetModel.Money(amount)) end
        local height=math.max(25,db.rowHeight+6)+(amount and 14 or 0); row:SetHeight(height)
        for slot,b in ipairs(row.bets) do
            b:ClearAllPoints(); b:SetPoint("TOPRIGHT",-(3-slot)*29,-1); b:SetShown(betting.visible)
            b:SetEnabled(not not (betting.canBet and target and (betting.snapshot and betting.snapshot.participants[target])))
            b.reason=betting.reason; row.reason=betting.reason
        end
        local won=r.resultConfirmed and not r.ambiguous and (p.isWinner or r.winner and
            ((p.playerGUID and r.winner.playerGUID and p.playerGUID==r.winner.playerGUID) or
            (not r.winner.playerGUID and p.playerName and p.playerName==r.winner.playerName)))
        row.winner:SetShown(not not won)
        y=y+height
    end
    for i=#rows+1,#f.rows do f.rows[i]:Hide() end
    f.rollHeading:ClearAllPoints(); f.rollHeading:SetPoint("TOPRIGHT",-betWidth-2,-2); f.rollHeading:SetText(hidden and "" or "ROLL")
    f.betHeading:SetShown(betting.visible)
    f.playerContent:SetSize(rowWidth,math.max(1,y))
    local scrollHeight=math.min(math.min(260,math.max(100,db.maxHeight-100)),math.max(25,y)); local scrolling=y>scrollHeight
    f.playerScroll:SetSize(rowWidth,scrollHeight)
    if f.playerScroll.ScrollBar then f.playerScroll.ScrollBar:SetShown(scrolling) end
    local width=rowWidth+(scrolling and 22 or 0)
    f.table:SetSize(width,scrollHeight+24)
    if f.tableRoll~=r then f.playerScroll:SetVerticalScroll(0); f.tableRoll=r end
    if f.playerScroll.GetVerticalScroll then f.playerScroll:SetVerticalScroll(math.min(f.playerScroll:GetVerticalScroll(),math.max(0,y-scrollHeight))) end
    return width,scrollHeight+24
end
function A.Render()
    local f=A.lootWindow; if not f then return end
    A.RefreshTooltipSettings()
    local db=A.db; local rolls=visibleRolls()
    if #rolls==0 then f.queueSize=nil end
    if db.presentation=="none" or #rolls==0 then f.itemTooltip:Hide(); f:Hide(); if A.ApplyNative then A.ApplyNative() end; return end
    local chosen
    for _,r in ipairs(rolls) do
        if db.betsEnabled then r.betPrivacy=true end
        if r==A.selected and r.choice~=nil and r.queueChoice==nil then chosen=r end
        r.queueChoice=r.choice
    end
    if chosen then A.selected=nextChoice(rolls,chosen) or chosen; A.queueReveal=true end
    local selectedIndex
    for i,r in ipairs(rolls) do if r==A.selected then selectedIndex=i end end
    if not selectedIndex then
        A.selected=nextChoice(rolls,rolls[#rolls]) or rolls[1]; A.queueReveal=true
        for i,r in ipairs(rolls) do if r==A.selected then selectedIndex=i end end
    end
    local r=A.selected; local changed=f.roll~=r; f.roll=r; f:SetScale(db.scale); f:SetAlpha(db.opacity); f:Show()
    if not f.dragging then f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",db.x,db.y) end
    local pending=0; for _,roll in ipairs(rolls) do if undecided(roll) then pending=pending+1 end end
    f.count:SetText(#rolls.." "..(#rolls==1 and "item" or "items")..(f.minimized and pending>0 and (" · "..pending.." to roll") or ""))
    f.close:SetEnabled(A.CanCloseQueue()); f.close:SetAlpha(A.CanCloseQueue() and 1 or 0.4)
    f.minimize:SetText(f.minimized and "+" or "-")
    f.lootrow:Show(); f.details:Show(); f.table:Show(); f.divider:Show()
    local size,reservedTableHeight=queueMetrics(f,rolls)
    local detailWidth,detailHeight=itemDetails(f,r)
    size.detailWidth=math.max(size.detailWidth,detailWidth)
    size.detailHeight=math.max(size.detailHeight,detailHeight)
    detailWidth,detailHeight=size.detailWidth,size.detailHeight
    local betting=A.InlineBetState(r)
    local tableWidth,tableHeight=partyTable(f,r,betting,size.nameWidth)
    tableHeight=math.max(tableHeight,reservedTableHeight)
    f.details:SetSize(detailWidth,detailHeight)
    f:SetSize(detailWidth+tableWidth+32,89+math.max(detailHeight,tableHeight)+10)
    f.divider:ClearAllPoints(); f.divider:SetPoint("TOPLEFT",detailWidth+17,-89); f.divider:SetPoint("BOTTOMLEFT",detailWidth+17,10)
    local actionCount=0
    for _,action in ipairs(actions) do
        local b=f.buttons[action.kind]; local allowed=action.kind==0 or r.allowed and r.allowed[action.kind]
        local show=action.kind<3 or allowed
        b:SetShown(not not show)
        if show then
            b:ClearAllPoints(); b:SetPoint("LEFT",actionCount*30,0); actionCount=actionCount+1
            b:SetEnabled(not not (undecided(r) and allowed))
            b.image:SetDesaturated(not (undecided(r) and allowed))
            b:SetAlpha(r.choice==action.kind and 1 or (undecided(r) and allowed and 1 or 0.45))
            b.reason=r.reasons and r.reasons[action.kind]
        end
    end
    f.actions:SetWidth(actionCount*30+4)
    local available=f:GetWidth()-28-f.actions:GetWidth()
    f.tabExtent=#rolls*48-2
    local overflow=f.tabExtent>available
    f.previous:SetShown(overflow); f.next:SetShown(overflow)
    f.next:ClearAllPoints(); f.next:SetPoint("RIGHT",f.actions,"LEFT",-1,0)
    f.previous:ClearAllPoints(); f.previous:SetPoint("RIGHT",f.next,"LEFT",0,0)
    f.tabViewport:SetWidth(math.max(46,available-(overflow and 38 or 0)))
    f.tabContent:SetWidth(math.max(f.tabExtent,f.tabViewport:GetWidth()))
    for i,roll in ipairs(rolls) do
        local b=f.tabButtons[i] or makeTab(f,i); b.roll=roll; b:Show()
        b.image:SetTexture(roll.texture or "Interface\\Icons\\INV_Misc_Dice_02")
        local active=roll==r; b.join:SetShown(active)
        b:SetBackdropColor(active and 0.09 or 0.14,active and 0.105 or 0.16,active and 0.09 or 0.13,1)
        b:SetBackdropBorderColor(active and 0.7 or 0.3,active and 0.85 or 0.34,active and 0.5 or 0.27,1)
        b.chosen:SetShown(roll.choice~=nil)
        if roll.finished then
            b.cooldown:Hide(); b.time:SetText(""); b.time:Hide()
        else
            if b.cooldownStarted~=roll.started or b.cooldownRoll~=roll then
                b.cooldown:SetCooldown(roll.started,roll.duration); b.cooldownStarted=roll.started; b.cooldownRoll=roll
            end
            b.cooldown:Show(); b.time:Show(); b.time:SetText(math.ceil(math.max(0,roll.started+roll.duration-GetTime())))
        end
        local outcome=roll.resultConfirmed and (roll.status=="You won" or roll.status=="You lost")
        b.result:SetShown(not not outcome)
        if outcome then b.result:SetColorTexture(roll.status=="You won" and 0.2 or 1,roll.status=="You won" and 1 or 0.2,0.2,0.22) end
        roll.frame=f
    end
    for i=#rolls+1,#f.tabButtons do f.tabButtons[i]:Hide() end
    A.QueueScroll(0)
    if changed or A.queueReveal then A.EnsureQueueTab(selectedIndex); A.queueReveal=nil end
    f.expandedHeight=f:GetHeight()
    if f.minimized then
        f.lootrow:Hide(); f.details:Hide(); f.itemTooltip:Hide(); f.table:Hide(); f.divider:Hide()
        f:SetHeight(34)
        if not f.dragging then
            f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",db.x,db.y+((f.minimizedHeight or f.expandedHeight)-34)/2)
        end
    end
    if A.ApplyNative then A.ApplyNative() end
end
