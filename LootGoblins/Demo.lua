local _,A=...
-- Simulation is only a data/clock adapter. Both sources enter A.rolls and use
-- QueueUI.lua, A.Choose, A.ApplyDrop, and the same inline-bet controls.
local samples={{5201,"Emberstone Staff","Interface\\Icons\\INV_Staff_13"},
    {12054,"Demon Band","Interface\\Icons\\INV_Jewelry_Ring_03"},
    {5967,"Girdle of Nobility","Interface\\Icons\\INV_Belt_10"}}
local function choiceState(kind) return ({[0]=5,[1]=0,[2]=3,[3]=3,[4]=2})[kind] end
local function simulation(r,index,generation)
    local S={roll=r,stakes={},total=0,values={}}
    -- Stable for this simulated drop, different across items and demo runs.
    -- Do not reseed or consume the client's global random stream.
    for slot=1,5 do S.values[slot]=(index*37+slot*19+generation*13)%100+1 end
    function S:Choose(kind)
        if r.finished or r.dismissed or r.choice~=nil or not r.allowed[kind] or GetTime()>=r.started+r.duration then return end
        local rows=A.Copy(r.rows); rows[1].state=choiceState(kind)
        rows[1].roll=kind~=0 and self.values[1] or nil
        A.ApplyDrop(r,{rollInfos=rows},GetTime())
    end
    function S:BetState()
        local participants={}; for _,p in ipairs(r.rows) do participants[p.playerGUID]=p.playerName end
        return {visible=not not A.db.betsEnabled,canBet=not r.finished and not r.dismissed,
            reason=r.finished and "finished" or nil,pool=self.total,
            mine=self.total>0 and {stake=self.total,targets=self.stakes} or nil,
            snapshot={participants=participants}}
    end
    function S:Bet(player,amount)
        if not self:BetState().canBet then return false,"finished" end
        local target=player.playerGUID
        if not target or not self:BetState().snapshot.participants[target] then return false,"target" end
        if amount>A.BetModel.MAX_MONEY-self.total then return false,"stake" end
        self.stakes[target]=(self.stakes[target] or 0)+amount; self.total=self.total+amount
        return true
    end
    return S
end
function A.Demo(count,preset)
    count=math.floor(math.max(1,math.min(40,count or (preset=="pattern" and 1 or 3))))
    A.demoGeneration=(A.demoGeneration or 0)+1
    local generation=A.demoGeneration
    for i=#A.rolls,1,-1 do if A.rolls[i].simulation then table.remove(A.rolls,i) end end
    local first
    for i=1,count do
        local sample=preset=="pattern" and {8395,"Pattern: Tough Scorpid Breastplate","Interface\\Icons\\INV_Scroll_04"} or samples[(i-1)%#samples+1]
        local link="item:"..sample[1]
        local name,full,quality,_,_,_,_,_,_,texture=GetItemInfo(link)
        local r=A.NewRoll(-i,full or link,GetTime(),60+i*2,nil)
        r.name=name or sample[2]; r.texture=texture or sample[3]; r.quality=quality or 3; r.demo=true
        r.allowed={[0]=true,[1]=true,[2]=true}
        r.rows={{playerName="You",playerGUID="demo:self",isSelf=true,playerClass="MAGE",state=4},
            {playerName="Thorn",playerGUID="demo:thorn",playerClass="WARRIOR",state=4},
            {playerName="Mira",playerGUID="demo:mira",playerClass="PRIEST",state=4},
            {playerName="Bram",playerGUID="demo:bram",playerClass="ROGUE",state=4},
            {playerName="Liora",playerGUID="demo:liora",playerClass="DRUID",state=4}}
        r.simulation=simulation(r,i,generation); A.rolls[#A.rolls+1]=r; first=first or r
        C_Timer.After(12+i,function()
            if generation~=A.demoGeneration or r.finished then return end
            local rows=A.Copy(r.rows); rows[2].state=0; rows[2].roll=r.simulation.values[2]
            rows[3].state=i%3==0 and 0 or 3; rows[3].roll=r.simulation.values[3]
            rows[4].state=5; A.ApplyDrop(r,{rollInfos=rows},GetTime()); A.Render()
        end)
        C_Timer.After(40+i,function()
            if generation~=A.demoGeneration then return end
            local rows=A.Copy(r.rows)
            if rows[1].state==4 then rows[1].state=5 end
            rows[2].state=0; rows[2].roll=r.simulation.values[2]
            rows[3].state=i%3==0 and 0 or 3; rows[3].roll=r.simulation.values[3]
            rows[4].state=5; rows[5].state=3; rows[5].roll=r.simulation.values[5]
            local winner,bestPriority
            for _,p in ipairs(rows) do
                p.isWinner=nil
                local priority=({[0]=1,[3]=2})[p.state]
                if priority and (not winner or priority<bestPriority or priority==bestPriority and (p.roll or 0)>winner.roll) then
                    winner=p; bestPriority=priority
                end
            end
            if winner then winner.isWinner=true end
            A.ApplyDrop(r,{rollInfos=rows},GetTime()); A.Render()
        end)
    end
    A.selected=first; A.queueReveal=true; A.db.presentation="queue"; A.Render()
    print("|cffb5d982LootGoblins:|r "..count.." simulated drops in the live loot queue. Results in about 40 seconds; no real loot, bets, or history are created.")
end
