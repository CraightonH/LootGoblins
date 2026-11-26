local addonName,A=...
A.rolls={}; A.byID={}
local events=CreateFrame("Frame")
local compatible=false
local function message(s) print("|cff73c7ffLootGoblins:|r "..s) end
local function readItem(r)
    local texture,name,count,quality,bop,need,greed,de,rn,rg,rd,skill,transmog=GetLootRollItemInfo(r.id)
    r.texture=texture; r.name=name; r.quality=quality; r.count=count; r.link=GetLootRollItemLink(r.id) or r.link
    r.allowed={[0]=true,[1]=need,[2]=greed,[3]=de,[4]=transmog}
    r.reasons={[1]=rn and _G["LOOT_ROLL_INELIGIBLE_REASON"..rn],
        [2]=rg and _G["LOOT_ROLL_INELIGIBLE_REASON"..rg],
        [3]=rd and _G["LOOT_ROLL_INELIGIBLE_REASON"..rd]}
end
local function finishUnknown(r,now,reason)
    if not r.finished then r.finished=now; r.status=reason or "Outcome unconfirmed" end
    A.RecordRoll(A.db,r)
end
local function drops()
    local list={}
    for _,enc in ipairs(C_LootHistory.GetAllEncounterInfos() or {}) do
        for _,drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(enc.encounterID) or {}) do
            local copy=A.Copy(drop); copy.encounterID=enc.encounterID; list[#list+1]=copy
        end
    end
    return list
end
function A.RefreshHistory()
    if not compatible then return end
    for _,r in ipairs(A.rolls) do
        if not r.demo and not r.closed and not r.finished and (not r.link or not r.name) then readItem(r) end
    end
    local list=drops(); A.Match(A.rolls,list)
    for _,r in ipairs(A.rolls) do
        if r.key and not r.demo then
            local d=C_LootHistory.GetSortedInfoForDrop(r.encounterID,r.lootListKey)
            if d then
                local previous=r.finished
                A.ApplyDrop(r,d,GetTime())
                A.RecordRoll(A.db,r)
                if r.finished and not previous and A.db.sound and SOUNDKIT then
                    PlaySound(r.status=="You won" and SOUNDKIT.UI_NEED_ROLL_POSITIVE or SOUNDKIT.UI_NEED_ROLL_NEGATIVE)
                end
            end
        end
    end
end
-- Preserve the client event/confirmation scripts. Only tracked roll presentations
-- are suppressed, and every mouse/alpha change is restored in Blizzard-only mode.
function A.ApplyNative()
    local function mouse(frame,suppress)
        if suppress then
            if frame.lootGoblinsMouse==nil then frame.lootGoblinsMouse=frame:IsMouseEnabled() and 1 or 0 end
            frame:EnableMouse(false)
        elseif frame.lootGoblinsMouse~=nil then
            frame:EnableMouse(frame.lootGoblinsMouse==1); frame.lootGoblinsMouse=nil
        end
        for _,child in ipairs({frame:GetChildren()}) do mouse(child,suppress) end
    end
    for i=1,4 do
        local frame=_G["GroupLootFrame"..i]
        if frame then
            local suppress=compatible and A.lootWindow and A.db.presentation=="queue" and frame.rollID and A.byID[frame.rollID]
            if suppress then
                if frame.lootGoblinsAlpha==nil then frame.lootGoblinsAlpha=frame:GetAlpha() end
                frame:SetAlpha(0)
            elseif frame.lootGoblinsAlpha~=nil then frame:SetAlpha(frame.lootGoblinsAlpha); frame.lootGoblinsAlpha=nil end
            mouse(frame,suppress)
        end
    end
end
function A.Choose(r,kind)
    if r.simulation then r.simulation:Choose(kind); A.Render(); return end
    if r.finished or r.closed or r.choice or not r.allowed[kind] then return end
    local left=GetLootRollTimeLeft(r.id)
    if not left or left<=0 then return end
    -- RollOnLoot may ask for Blizzard's normal binding confirmation. Do not
    -- claim a choice until its post-confirmation hook/history confirms it.
    RollOnLoot(r.id,kind)
end
local function choiceConfirmed(id,kind)
    local r=A.byID[id]
    if r then r.choice=kind; A.Render() end
end
local function startRoll(id,duration)
    if A.byID[id] and not A.byID[id].finished then return end
    local now=GetTime()
    local r=A.NewRoll(id,GetLootRollItemLink(id),now,(duration or 60000)/1000,C_LootHistory.GetLootHistoryTime())
    A.StartRecord(r)
    readItem(r)
    -- A second identical drop invalidates a prior speculative association.
    for _,other in ipairs(A.rolls) do
        if not other.demo and other.link==r.link and r.link and math.abs(other.historyStarted-r.historyStarted)<=8 then
            other.key=nil; other.encounterID=nil; other.lootListKey=nil
            other.rows={}; other.status="Rolling"; other.finished=nil; other.dismissed=nil
            other.ambiguous=true; r.ambiguous=true
            other.resultConfirmed=nil; other.winner=nil
            other.match="Identical drops: history association uncertain"
            r.match=other.match
            A.RecordRoll(A.db,other,true)
        end
    end
    A.byID[id]=r; A.rolls[#A.rolls+1]=r
    if not A.selected or A.selected.dismissed or A.selected.finished or A.selected.choice~=nil then
        A.selected=r; A.queueReveal=true
    end
    A.Render()
    C_Timer.After(0.6,function() A.RefreshHistory(); A.Render(); A.ApplyNative() end)
end
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    if not A.db then return end
    elapsed=elapsed+dt; if elapsed<0.25 then return end; elapsed=0
    local now=GetTime()
    for _,r in ipairs(A.rolls) do
        if not r.demo and not r.finished and now-r.started>r.duration+10 then
            finishUnknown(r,now,"Outcome unconfirmed")
        end
        local hovered=r.frame and r.frame:IsShown() and r.frame:IsMouseOver()
        if A.ShouldClose(r,A.db,now,hovered) then r.dismissed=true end
        if r.finished then A.RecordRoll(A.db,r) end
    end
    -- Keep live and pinned records regardless of the completed-history limit.
    local completed=0
    for i=#A.rolls,1,-1 do
        local r=A.rolls[i]
        if r.finished and r.dismissed and not r.pinned then
            completed=completed+1
            if completed>A.db.historyLimit then
                if A.byID[r.id]==r then A.byID[r.id]=nil end
                table.remove(A.rolls,i)
            end
        end
    end
    if compatible then
        -- Polling catches reordered/missed history events; no chat parsing.
        A.poll=(A.poll or 0)+0.25
        if A.poll>=1 then A.poll=0; A.RefreshHistory(); A.RefreshStatsIfVisible() end
    end
    if A.betClient then A.betClient:Tick() end
    if A.betWindow and A.betWindow:IsShown() then A.RenderBets() end
    A.Render()
end)
events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        local name=...; if name~=addonName then return end
        LootGoblinsDB=A.InitDB(LootGoblinsDB); A.db=LootGoblinsDB
        A.InitHistory(A.db)
        compatible=C_LootHistory and C_LootHistory.GetAllEncounterInfos and
            C_LootHistory.GetSortedDropsForEncounter and C_LootHistory.GetSortedInfoForDrop and C_LootHistory.GetLootHistoryTime and
            GetLootRollItemInfo and GetLootRollItemLink and RollOnLoot
        A.BuildUI()
        A.InitBetting()
        A.RegisterSettings()
        if compatible then
            for _,e in ipairs({"START_LOOT_ROLL","CANCEL_LOOT_ROLL","CANCEL_ALL_LOOT_ROLLS",
                "LOOT_HISTORY_UPDATE_DROP","LOOT_HISTORY_UPDATE_ENCOUNTER","LOOT_HISTORY_CLEAR_HISTORY","GET_ITEM_INFO_RECEIVED"}) do
                events:RegisterEvent(e)
            end
            -- Submission without auto-confirmation. Blizzard owns bind prompts.
            if ConfirmLootRoll then hooksecurefunc("ConfirmLootRoll",choiceConfirmed) end
            hooksecurefunc("RollOnLoot",function(id,kind)
                local r=A.byID[id]; if r then r.submitted=kind end
            end)
            for i=1,4 do
                local f=_G["GroupLootFrame"..i]
                if f then f:HookScript("OnShow",function() A.ApplyNative() end) end
            end
        else message("This client has an unsupported loot API. Default loot UI remains available; /lg demo shows the preview.") end
        SLASH_LOOTGOBLINS1="/lg"; SLASH_LOOTGOBLINS2="/lootgoblins"
        SlashCmdList.LOOTGOBLINS=function(input)
            local cmd=(input or ""):lower():match("^%s*(%S+)")
            if cmd=="demo" then A.Demo(tonumber((input or ""):match("%s+(%d+)")),(input or ""):lower():match("^%s*demo%s+(pattern)%s*$"))
            elseif cmd=="history" then A.OpenHistory("drops")
            elseif cmd=="stats" then A.OpenHistory("players")
            elseif cmd=="export" then A.OpenExport()
            elseif cmd=="bets" then A.OpenBets()
            elseif cmd=="session" then A.OpenHistory("drops")
            elseif cmd=="queue" then A.db.presentation="queue"; A.ApplyNative(); A.Render()
            elseif cmd=="native" then A.db.presentation="none"; A.ApplyNative(); A.Render(); message("Default loot popups restored.")
            elseif cmd=="clear" then
                for _,r in ipairs(A.rolls) do if r.finished then r.dismissed=true; r.pinned=false end end; A.Render()
            else A.OpenSettings() end
        end
    elseif event=="START_LOOT_ROLL" then startRoll(...)
    elseif event=="CANCEL_LOOT_ROLL" then
        local id=...; if A.byID[id] then A.byID[id].closed=true end
        A.RefreshHistory(); A.Render()
    elseif event=="CANCEL_ALL_LOOT_ROLLS" then
        for _,r in ipairs(A.rolls) do if not r.finished and not r.demo then r.closed=true; finishUnknown(r,GetTime(),"Roll cancelled · outcome unconfirmed") end end
        A.Render()
    elseif event=="GET_ITEM_INFO_RECEIVED" then
        A.itemSizeRevision=(A.itemSizeRevision or 0)+1
        if A.lootWindow then A.lootWindow.itemTooltip.queueLink=nil end; A.Render()
    elseif event=="LOOT_HISTORY_CLEAR_HISTORY" then
        for _,r in ipairs(A.rolls) do if r.key and not r.finished then
            r.key=nil; r.match="Loot history was cleared"; finishUnknown(r,GetTime())
        end end
        A.Render()
    else A.RefreshHistory(); A.Render() end
end)
events:RegisterEvent("ADDON_LOADED")
