local A={}; local now=100; local calls=0; local timers={}; local created={}
local base=os.getenv("LOOTGOBLINS_ADDON") or "LootGoblins"
local frameMethods={}
function frameMethods:SetScript(k,v) self.scripts[k]=v end
function frameMethods:GetScript(k) return self.scripts[k] end
function frameMethods:HookScript(k,v)
    local old=self.hooks[k]
    self.hooks[k]=function(...) if old then old(...) end; v(...) end
end
function frameMethods:GetChildren() return (table.unpack or unpack)(self.children) end
function frameMethods:CreateFontString() return setmetatable({children={},scripts={},hooks={}}, {__index=frameMethods}) end
frameMethods.CreateTexture=frameMethods.CreateFontString
function frameMethods:SetSize(w,h) self.width=w; self.height=h end
function frameMethods:SetWidth(w) self.width=w end
function frameMethods:SetHeight(h) self.height=h end
function frameMethods:GetWidth() return self.width or 300 end
function frameMethods:GetHeight() return self.height or 80 end
function frameMethods:SetText(s) self.text=s end
function frameMethods:GetText() return self.text end
function frameMethods:SetShown(v) self.shown=not not v end
function frameMethods:Show()
    self.shown=true
    if self.pendingItemSize then self:SetSize(self.pendingItemSize[1],self.pendingItemSize[2]); self.pendingItemSize=nil end
end
function frameMethods:Hide() self.shown=false end
function frameMethods:IsShown() return self.shown end
function frameMethods:IsMouseOver() return false end
function frameMethods:IsMouseEnabled() return self.mouse~=false end
function frameMethods:EnableMouse(v) self.mouse=v end
function frameMethods:GetAlpha() return self.alpha or 1 end
function frameMethods:SetAlpha(v) self.alpha=v end
function frameMethods:GetFrameLevel() return self.level or 1 end
function frameMethods:SetFrameLevel(n) self.level=n end
function frameMethods:GetCenter() return self.centerX or 500,self.centerY or 400 end
function frameMethods:GetEffectiveScale() return self.effectiveScale or 1 end
function frameMethods:SetChecked(v) self.checked=v end
function frameMethods:GetChecked() return self.checked end
function frameMethods:SetEnabled(v) self.enabled=v end
function frameMethods:SetPoint(...) self.point={...} end
local harmless={"SetFont","SetJustifyH","SetJustifyV","SetBackdrop","SetBackdropColor","SetBackdropBorderColor",
    "HasFocus","SetNormalFontObject","SetHighlightFontObject","SetAllPoints","SetTexture","SetStatusBarTexture","SetStatusBarColor","SetMinMaxValues","SetValue",
    "SetMovable","SetClampedToScreen","RegisterForDrag","StartMoving","StopMovingOrSizing","SetFrameStrata",
    "SetScrollChild","SetScale","ClearAllPoints","SetTextColor","SetAutoFocus","SetMaxLetters","ClearFocus",
    "RegisterEvent","UnregisterAllEvents","SetColorTexture","SetMultiLine","HighlightText","SetFocus"}
for _,name in ipairs(harmless) do frameMethods[name]=function() end end
function frameMethods:SetValue(v) self.value=v end
function frameMethods:SetMinMaxValues(a,b) self.minimum=a; self.maximum=b end
function frameMethods:SetStatusBarColor(r,g,b) self.color={r,g,b} end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({children={},scripts={},hooks={},shown=true},{__index=frameMethods})
    f.template=template; f.frameName=name
    if template=="InternalEmbeddedItemTooltipTemplate" then
        f.Tooltip=CreateFrame("GameTooltip",name.."Tooltip",f,"GameTooltipTemplate")
        f.Tooltip.IsEmbedded=true
    end
    f.parent=parent
    if parent then table.insert(parent.children,f) end
    created[#created+1]=f; return f
end
local registered,opened
Settings={RegisterCanvasLayoutCategory=function(panel,name)
    registered={panel=panel,name=name,GetID=function() return 42 end}; return registered
end,RegisterAddOnCategory=function(category) assert(category==registered) end,
OpenToCategory=function(id) opened=id end}
UIParent=CreateFrame("Frame"); STANDARD_TEXT_FONT="mock.ttf"; RAID_CLASS_COLORS={}; SlashCmdList={}
UIParent:SetSize(1920,1080)
GameTooltip=CreateFrame("Frame"); C_Timer={After=function(delay,fn) timers[#timers+1]=fn end}
function GetTime() return now end
function GetLootRollItemInfo() return "icon","Sword",1,3,false,true,true,false,nil,nil,nil,nil,false end
function GetLootRollItemLink() return "item:mock" end
function GetLootRollTimeLeft() return 60000 end
function RollOnLoot() calls=calls+1 end
function ConfirmLootRoll() end
function hooksecurefunc(name,fn)
    local original=_G[name]; _G[name]=function(...) original(...); fn(...) end
end
local history={}
C_LootHistory={GetLootHistoryTime=function() return now end,GetAllEncounterInfos=function() return {{encounterID=1}} end,
    GetSortedDropsForEncounter=function() return history end,GetSortedInfoForDrop=function(_,key)
    for _,drop in ipairs(history) do if drop.lootListKey==key then return drop end end
end}
for i=1,4 do _G["GroupLootFrame"..i]=CreateFrame("Frame",nil,UIParent) end

function frameMethods:GetStringWidth() return #(self.text or "")*6 end
function frameMethods:GetStringHeight()
    local lines=1; for _ in (self.text or ""):gmatch("\n") do lines=lines+1 end; return lines*14
end
function frameMethods:SetHorizontalScroll(v) self.scrollX=v end
function frameMethods:GetHorizontalScroll() return self.scrollX or 0 end
function frameMethods:SetVerticalScroll(v) self.scrollY=v end
function frameMethods:GetVerticalScroll() return self.scrollY or 0 end
function frameMethods:SetCooldown(start,duration) self.cooldownStart=start; self.cooldownDuration=duration end
function frameMethods:SetOwner(owner) self.owner=owner end
local itemSizes={}; local recipeItems={}; local tooltipAddonEnabled=false; local pricingAddonEnabled=false
function frameMethods:SetHyperlink(link)
    if self.hooks.OnTooltipCleared then self.hooks.OnTooltipCleared(self) end
    self.link=link
    local size=itemSizes[link] or {250,200}
    self.pendingItemSize={size[1],size[2]}; self.rankingLines=false; self.recipeOutputLink=nil
    local recipe=recipeItems[link]
    if recipe and recipe.ready and self.ItemTooltip then
        self.recipeOutputLink=recipe.output
        self.ItemTooltip:Show()
        self.pendingItemSize={recipe.width,recipe.height}
        size=self.pendingItemSize
    end
    -- Reproduce GearQuestForever's global postprocessor and duplicate guard.
    -- Its cleanup normally hooks only Blizzard's two standard tooltips.
    if tooltipAddonEnabled and not self.gqSkipScoreHook and not self.gqScoreLineAdded then
        self.gqScoreLineAdded=true; self.gqEnchantAdded=true; self.rankingLines=true
        self.pendingItemSize={size[1]+38,size[2]+84}
    end
    -- Auctionator validates custom tooltips by the NotGameTooltip prefix.
    self.pricingLines=false
    if pricingAddonEnabled and (self.frameName or ""):match("^NotGameTooltip") then
        self.pricingLines=true
        self.pendingItemSize={self.pendingItemSize[1],self.pendingItemSize[2]+24}
    end
end
function frameMethods:RefreshData()
    self.shouldRefreshData=false; self:SetHyperlink(self.link); self:Show()
end
local nativeTooltipUpdates=0
function GameTooltip_OnUpdate(self)
    nativeTooltipUpdates=nativeTooltipUpdates+1
    if self.shouldRefreshData then self:RefreshData() end
end
function GameTooltip_CalculatePadding() end
function frameMethods:ClearAllPoints() self.point=nil end
for _,name in ipairs({"EnableMouseWheel","SetHighlightTexture","SetDesaturated","SetDrawEdge","SetDrawBling","SetHideCountdownNumbers"}) do
    frameMethods[name]=function() end
end
local remaining=60000
function GetLootRollTimeLeft() return remaining end
function GetItemInfo(link) return "Sample item",link,3,nil,nil,nil,nil,nil,nil,"sample-icon" end
function UnitGUID(unit) return unit=="player" and "P1" or "P"..(tonumber(unit:match("%d+")) or 1)+1 end
function UnitFullName(unit) return unit=="player" and "You" or "Party"..unit,"Realm" end
function UnitIsConnected() return true end
function IsInGroup() return true end
function IsInRaid() return false end
function GetNumSubgroupMembers() return 4 end
C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,SendAddonMessage=function() return true end}
local manifest=assert(io.open(base.."/LootGoblins.toc")):read("*a")
for file in manifest:gmatch("([^\r\n]+%.lua)") do
    assert(loadfile(base.."/"..file))("LootGoblins",A)
end
local eventFrame=created[#created]
LootGoblinsDB={presentation="native",locked=false}
eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","LootGoblins")
assert(A.db.presentation=="queue" and A.lootWindow)
assert(registered.name=="LootGoblins" and A.settings)
A.OpenSettings(); assert(opened==42)
GroupLootFrame1.rollID=10
eventFrame.scripts.OnEvent(eventFrame,"START_LOOT_ROLL",10,60000)
local r=A.rolls[1]; local f=A.lootWindow
assert(f:IsShown() and f.roll==r and not A.window,"live loot uses only the queue")
assert(GroupLootFrame1:GetAlpha()==0 and not GroupLootFrame1:IsMouseEnabled(),"tracked native frame must not duplicate the queue")
assert(GroupLootFrame2:GetAlpha()==1,"untracked native frames remain usable")
assert(f.buttons[1].enabled and f.buttons[2].enabled and f.buttons[0].enabled)
assert(f.itemTooltip.link==r.link,"details must use the full game item tooltip")
assert(f.tabButtons[1].cooldown.cooldownDuration==60)
assert(not f.previous:IsShown() and not f.next:IsShown(),"no scroll controls for one tab")
assert(f.actions:GetFrameLevel()>f.tabViewport:GetFrameLevel())
assert(not f.close.enabled and not A.CloseQueue(),"cannot close before choosing")
local expandedHeight=f:GetHeight(); local originalY=A.db.y
f.minimize.scripts.OnClick(f.minimize)
assert(f:IsShown() and f:GetHeight()==34 and f.minimized)
assert(not f.lootrow:IsShown() and not f.details:IsShown() and not f.table:IsShown())
assert(not f.itemTooltip:IsShown() and not f.close.enabled)
assert(f.point[5]==originalY+(expandedHeight-34)/2,"minimizing must keep the header in place")
A.Render(); assert(f:GetHeight()==34,"background refresh must preserve minimized state")
f.minimize.scripts.OnClick(f.minimize)
assert(f:GetHeight()==expandedHeight and not f.minimized and A.db.y==originalY)
assert(f.details:IsShown() and f.itemTooltip:IsShown())
A.db.presentation="none"; A.Render()
assert(not f:IsShown() and GroupLootFrame1:GetAlpha()==1 and GroupLootFrame1:IsMouseEnabled())
A.db.presentation="queue"; A.Render()
A.Choose(r,1); assert(calls==1 and r.choice==nil,"submission waits for binding confirmation/history")
ConfirmLootRoll(10,1); assert(r.choice==1 and f.close.enabled,"confirmed selection unlocks close")
A.Choose(r,2); assert(calls==1,"confirmed choices cannot be submitted twice")
history={{lootListKey=2,itemHyperlink="item:mock",startTime=100,rollInfos={
    {playerName="You",playerGUID="P1",isSelf=true,state=0,roll=44},
    {playerName="Zed",playerGUID="P2",state=3,roll=99},
    {playerName="Amy",playerGUID="P3",state=5}}}}
A.RefreshHistory(); A.Render()
assert(r.key=="1:2" and f.rows[1].player.isSelf)
local withoutBets=f:GetWidth()
A.db.betsEnabled=true; A.Render(); local withBets=f:GetWidth()
assert(withBets>withoutBets and f.betHeading:IsShown(),"betting adds only the width it requires")
assert(f.rows[1].player.playerName=="Amy" and f.rows[1].value.text=="Hidden","blind mode uses stable name order")
assert(not f.rows[1].choice:IsShown(),"passes are concealed")
remaining=0
assert(A.PlaceInlineBet(r,history[1].rollInfos[2],1),"zero timer before resolution must not close betting")
assert(A.PlaceInlineBet(r,history[1].rollInfos[2],100))
assert(A.InlineBetState(r).mine.stake==101)
A.db.betsEnabled=false; A.Render()
assert(f:GetWidth()==withoutBets and not f.betHeading:IsShown())
assert(f.rows[1].value.text=="Hidden","turning betting off cannot reveal a previously blinded item")
for _,row in ipairs(f.rows) do for _,b in ipairs(row.bets) do assert(not b:IsShown()) end end
A.ApplyDrop(r,{rollInfos={{playerName="You",playerGUID="P1",isSelf=true,state=0,roll=44,isWinner=true},
    {playerName="Zed",playerGUID="P2",state=3,roll=99},{playerName="Amy",playerGUID="P3",state=5}}},now)
A.Render(); assert(f.rows[1].winner:IsShown() and f.rows[1].value.text=="44")
assert(not f.resultGlow,"queue outcomes must not draw a full-window border")
remaining=60000
local before=#A.rolls; local beforeCalls=calls; local beforeTimers=#timers
itemSizes["item:12054"]={310,340}
A.Demo(10)
assert(#A.rolls==before+10 and A.selected.simulation)
local demo=A.selected
local fixedWidth,fixedHeight=f:GetWidth(),f:GetHeight()
assert(fixedHeight==340+99 and f.queueSize.detailWidth==314,"measure the real dimensions of an unvisited tooltip after its layout is shown")
for _,tab in ipairs(f.tabButtons) do
    if tab:IsShown() then
        tab.scripts.OnClick(tab)
        assert(f:GetWidth()==fixedWidth and f:GetHeight()==fixedHeight,"switching item descriptions must not resize the window")
    end
end
A.selected=demo; A.Render()
assert(f==A.lootWindow and f.roll==demo,"demo and real rolls must share the exact window")
assert(f.itemTooltip.link==demo.link,"demo item descriptions use the same GameTooltip")
assert(not demo.nativeDemo and not demo.retainedFrame and not demo.nativeCard)
assert(f.previous:IsShown() and f.next:IsShown(),"ten tabs overflow")
local actionWidth=f.actions:GetWidth(); local queueWidth=f:GetWidth()
A.QueueScroll(99999); assert(f.tabOffset>0 and f.actions:GetWidth()==actionWidth and f:GetWidth()==queueWidth)
for i=1,9 do
    local selected=A.selected
    f.buttons[1].scripts.OnClick(f.buttons[1]); assert(selected.choice==1)
    assert(A.selected~=selected and A.selected.choice==nil)
end
assert(calls==beforeCalls,"simulated choices must never call the server")
assert(not f.close.enabled and not A.CloseQueue(),"one remaining unchosen item must keep the close button locked")
assert(f.tabOffset>0,"auto advance reveals the selected tab")
A.db.betsEnabled=true; A.Render()
local current=A.selected
local p=current.rows[2]
assert(A.PlaceInlineBet(current,p,1)); assert(A.PlaceInlineBet(current,p,100)); assert(A.PlaceInlineBet(current,p,10000))
assert(A.InlineBetState(current).mine.stake==10101)
assert(A.PlaceInlineBet(current,current.rows[3],100))
assert(A.InlineBetState(current).mine.stake==10201)
-- Drive the simulation clock/event adapter, not another renderer.
for i=beforeTimers+1,#timers do timers[i]() end
A.Render(); assert(current.finished and not A.InlineBetState(current).canBet)
local previousRoll
for _,roll in ipairs(A.rolls) do
    if roll.simulation then
        assert(roll.rows[2].roll>=1 and roll.rows[2].roll<=100)
        assert(roll.rows[2].roll~=previousRoll,"each simulated item must have its own rolls")
        previousRoll=roll.rows[2].roll
        local winner=assert(roll.winner)
        for _,p in ipairs(roll.rows) do
            if p.state==0 then assert(winner.state==0) end
            if p.state==winner.state then assert((p.roll or 0)<=winner.roll) end
        end
    end
end
for _,tab in ipairs(f.tabButtons) do
    if tab:IsShown() and tab.roll.finished then
        assert(not tab.time:IsShown() and tab.time:GetText()=="","completed tabs must clear the countdown rather than draw a missing-font glyph")
    end
end
assert(not A.PlaceInlineBet(current,p,1))
assert(calls==beforeCalls)
local archiveCount=#A.db.lootArchive.records
for _,roll in ipairs(A.rolls) do if roll.simulation then A.RecordRoll(A.db,roll) end end
assert(#A.db.lootArchive.records==archiveCount,"simulation never pollutes history")
local retainedWidth,retainedHeight=f:GetWidth(),f:GetHeight()
for _,roll in ipairs(A.rolls) do if roll.link=="item:12054" then roll.dismissed=true end end
A.Render()
assert(f:GetWidth()==retainedWidth and f:GetHeight()==retainedHeight,"removing the largest item must not shrink the active queue")
local oldGeneration=A.demoGeneration
A.Demo(1); assert(A.demoGeneration==oldGeneration+1)
local demos=0; for _,roll in ipairs(A.rolls) do if roll.simulation then demos=demos+1 end end
assert(demos==1 and not f.next:IsShown(),"restarting demo replaces samples and hides unnecessary scroll controls")
for _,tab in ipairs(f.tabButtons) do
    if tab.roll==A.selected then assert(tab.time:IsShown() and tonumber(tab.time:GetText()),"reused tabs must restore the numeric countdown") end
end
local started=A.selected.started; now=started+80
A.Render(); assert(not f.buttons[1].enabled,"expired choice buttons are disabled")
A.db.betsEnabled=true
assert(A.InlineBetState(A.selected).canBet,"simulation betting remains open until its result, just like live loot")
-- A completely new queue must size itself from its own items, not retain the
-- previous queue's maximum or a fixed tooltip width/height floor.
A.db.betsEnabled=false
A.rolls={}; A.selected=nil; A.Render()
itemSizes["item:5201"]={180,120}
A.Demo(1)
assert(f.queueSize.detailWidth==184 and f.queueSize.detailHeight==120)
assert(f:GetHeight()==248 and f:GetWidth()<fixedWidth,"a smaller new queue must actually be smaller")
local compactWidth,compactHeight=f:GetWidth(),f:GetHeight()
A.Demo(1)
assert(f:GetWidth()==compactWidth and f:GetHeight()==compactHeight,"demo replacement must start a fresh size batch without an empty render")
-- Close dismisses presentation only, and later outcomes must not reopen it.
assert(not f.close.enabled)
local closable=A.selected
f.buttons[0].scripts.OnClick(f.buttons[0])
assert(closable.choice==0 and f.close.enabled,"Pass must also unlock closing")
f.close.scripts.OnClick(f.close)
assert(closable.queueHidden and not closable.dismissed and not f:IsShown())
A.ApplyDrop(closable,{rollInfos={{playerName="You",playerGUID="demo:self",isSelf=true,state=5},
    {playerName="Thorn",playerGUID="demo:thorn",state=0,isWinner=true,roll=87}}},now)
A.Render(); assert(not f:IsShown(),"background resolution must not reopen a closed pane")
A.Demo(1); assert(f:IsShown() and not f.close.enabled,"new loot must reopen the pane with close locked")
-- Real GameTooltips can ignore their parent's UI scale. Both the measuring
-- tooltip and the displayed tooltip must be converted into queue-local units.
A.rolls={}; A.selected=nil; A.Render()
f.effectiveScale=1.25
f.measureTooltip.effectiveScale=1; f.itemTooltip.effectiveScale=1
A.Demo(3)
assert(math.abs(f.queueSize.detailWidth-252)<0.01 and math.abs(f.queueSize.detailHeight-272)<0.01,
    "a 310x340 tooltip at scale 1 must occupy 252x272 queue units at scale 1.25")
local scaledWidth,scaledHeight=f:GetWidth(),f:GetHeight()
for _,tab in ipairs(f.tabButtons) do
    if tab:IsShown() then
        tab.scripts.OnClick(tab)
        assert(f:GetWidth()==scaledWidth and f:GetHeight()==scaledHeight,"scaled tab switching must remain stable")
    end
end
f.effectiveScale=1; A.Render()
assert(f.queueSize.detailWidth==314 and f.queueSize.detailHeight==340,"changing UI scale must refresh measurements without retaining the previous scale")
-- GearQuestForever-like text must be preserved on every population, not only
-- the first item ever shown in a custom tooltip.
tooltipAddonEnabled=true
A.rolls={}; A.selected=nil; A.Render(); A.Demo(3)
local decoratedWidth,decoratedHeight=f:GetWidth(),f:GetHeight()
for cycle=1,3 do
    for _,tab in ipairs(f.tabButtons) do
        if tab:IsShown() then
            tab.scripts.OnClick(tab)
            assert(f.itemTooltip.rankingLines,"returning to an item must retain addon-provided tooltip lines")
            local measured=tab.roll.queueItemSize
            assert(measured.width==f.itemTooltip:GetWidth()+4 and measured.height==f.itemTooltip:GetHeight(),
                "measure and display must contain exactly the same addon additions")
            assert(f:GetWidth()==decoratedWidth and f:GetHeight()==decoratedHeight)
        end
    end
end
f.minimize.scripts.OnClick(f.minimize); f.minimize.scripts.OnClick(f.minimize)
assert(f.itemTooltip.rankingLines,"minimize/restore must retain tooltip additions")
eventFrame.scripts.OnEvent(eventFrame,"GET_ITEM_INFO_RECEIVED",5201,true)
assert(f.itemTooltip.rankingLines and f.measureTooltip.rankingLines,"item cache refresh must restore additions on both tooltip paths")
assert(f:GetWidth()==decoratedWidth and f:GetHeight()==decoratedHeight,"refresh must not duplicate added lines and grow the window")
-- Verify that two live drops read distinct server history entries too.
A.rolls={}; A.byID={}; A.selected=nil; history={}; A.Render()
function GetLootRollItemLink(id) return "item:"..id end
eventFrame.scripts.OnEvent(eventFrame,"START_LOOT_ROLL",201,60000)
eventFrame.scripts.OnEvent(eventFrame,"START_LOOT_ROLL",202,60000)
history={{lootListKey=201,itemHyperlink="item:201",startTime=now,rollInfos={
    {playerName="You",isSelf=true,playerGUID="P1",state=0,roll=12,isWinner=true},
    {playerName="Other",playerGUID="P2",state=3,roll=99}}},
    {lootListKey=202,itemHyperlink="item:202",startTime=now,rollInfos={
    {playerName="You",isSelf=true,playerGUID="P1",state=0,roll=31},
    {playerName="Other",playerGUID="P2",state=0,roll=74,isWinner=true}}}}
A.RefreshHistory(); A.Render()
assert(A.byID[201].rows[1].roll==12 and A.byID[202].rows[1].roll==31,"live drops must retain their own server rolls")
assert(A.byID[201].winner.playerGUID=="P1" and A.byID[202].winner.playerGUID=="P2")
-- A recipe can finish loading through TOOLTIP_DATA_UPDATE without another
-- GET_ITEM_INFO_RECEIVED for the pattern. Its crafted item must then render
-- and contribute to the same measurements used for all queued items.
tooltipAddonEnabled=false
A.rolls={}; A.selected=nil; A.Render()
itemSizes["item:8395"]={270,120}
recipeItems["item:8395"]={output="item:8203",width=320,height=340,ready=false}
SlashCmdList.LOOTGOBLINS("demo pattern")
assert(A.selected.link=="item:8395" and #A.rolls==1,"pattern demo must drive the same queue with the real recipe item")
assert(f.itemTooltip.ItemTooltip and f.measureTooltip.ItemTooltip)
assert(f.itemTooltip.ItemTooltip.Tooltip.IsEmbedded)
assert(not f.itemTooltip.recipeOutputLink)
local loadingHeight=f:GetHeight()
recipeItems["item:8395"].ready=true
f.itemTooltip.shouldRefreshData=true
local previousNativeUpdates=nativeTooltipUpdates
f.itemTooltip.scripts.OnUpdate(f.itemTooltip,0.1)
assert(not f.itemTooltip.shouldRefreshData and nativeTooltipUpdates>previousNativeUpdates,"recipe notifications must use the native tooltip updater")
A.Render()
assert(f.itemTooltip.recipeOutputLink=="item:8203" and f.itemTooltip.ItemTooltip:IsShown())
assert(f.measureTooltip.recipeOutputLink=="item:8203","measurement must include the crafted result too")
assert(f.queueSize.detailHeight==340 and f:GetHeight()>loadingHeight,"recipe output must fit inside the pane")
f.minimize.scripts.OnClick(f.minimize); f.minimize.scripts.OnClick(f.minimize)
assert(f.itemTooltip.recipeOutputLink=="item:8203" and f.itemTooltip.ItemTooltip:IsShown())
A.Demo(1)
assert(not f.itemTooltip.recipeOutputLink and not f.itemTooltip.ItemTooltip:IsShown(),"normal items must not retain the previous recipe's preview")
-- Standard custom-tooltip registration must opt both paths into pricing,
-- and pricing/ranking additions must coexist without duplication on tab swaps.
pricingAddonEnabled=true; tooltipAddonEnabled=true
A.rolls={}; A.selected=nil; A.Render(); A.Demo(3)
local pricedWidth,pricedHeight=f:GetWidth(),f:GetHeight()
for cycle=1,2 do
    for _,tab in ipairs(f.tabButtons) do
        if tab:IsShown() then
            tab.scripts.OnClick(tab)
            assert(f.itemTooltip.pricingLines and f.itemTooltip.rankingLines)
            assert(f.measureTooltip.pricingLines)
            assert(f:GetWidth()==pricedWidth and f:GetHeight()==pricedHeight)
        end
    end
end
-- Each supported addon has an independent persisted checkbox. Changing one
-- must immediately affect both the displayed and measured item details.
local function tooltipSetting(key,value)
    local checkbox=assert(A.settingsChecks[key],"missing tooltip addon checkbox")
    checkbox:SetChecked(value); checkbox.scripts.OnClick(checkbox)
    assert(A.db[key]==value)
end
for _,auction in ipairs({false,true}) do
    for _,gear in ipairs({false,true}) do
        tooltipSetting("tooltipAuctionator",auction)
        tooltipSetting("tooltipGearQuest",gear)
        assert(f.itemTooltip.pricingLines==auction and f.itemTooltip.rankingLines==gear,
            "addon checkboxes must independently control the embedded tooltip")
        assert(f.measureTooltip.pricingLines==auction and f.measureTooltip.rankingLines==gear,
            "measurement must honor the same addon settings")
        assert(f.itemTooltip.ItemTooltip.Tooltip.gqSkipScoreHook==not gear)
        local width,height=f:GetWidth(),f:GetHeight()
        for _,tab in ipairs(f.tabButtons) do
            if tab:IsShown() then
                tab.scripts.OnClick(tab)
                assert(f.itemTooltip.pricingLines==auction and f.itemTooltip.rankingLines==gear)
                assert(f:GetWidth()==width and f:GetHeight()==height)
            end
        end
    end
end
assert(GameTooltip.gqSkipScoreHook==nil,"checkboxes must not alter Blizzard's shared tooltip")
-- One source of rendering truth: no native/demo presentation dependencies in TOC.
local toc=assert(io.open(base.."/LootGoblins.toc")):read("*a")
assert(toc:find("QueueUI.lua",1,true) and not toc:find("NativeUI.lua",1,true) and not toc:find("Demo.xml",1,true))
local source=assert(io.open(base.."/QueueUI.lua")):read("*a")
assert(not source:find("r.demo",1,true) and not source:find("r.simulation",1,true),"renderer cannot branch on demo/live source")
print("PASS shared live/demo queue, native suppression/restore, full tooltips, scrolling, fixed actions, auto advance, privacy, sizing, repeat bets, outcomes and persistence")
