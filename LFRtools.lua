LFRtools = {};

LFRtools.frame = CreateFrame("Frame", "LFRtools");
LFRtools.frame:RegisterEvent("ADDON_LOADED");
LFRtools.frame:RegisterEvent("INSPECT_READY");
LFRtools.frame:RegisterEvent("PLAYER_ALIVE");
LFRtools.frame:RegisterEvent("READY_CHECK");
--Group scan
LFRtools.frame:RegisterEvent("RAID_INSTANCE_WELCOME");
LFRtools.frame:RegisterEvent("GROUP_JOINED");
LFRtools.frame:RegisterEvent("PARTY_LEADER_CHANGED");
--Member scan
--LFRtools.frame:RegisterEvent("UNIT_CONNECTION");
LFRtools.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
LFRtools.frame:RegisterEvent("ROLE_CHANGED_INFORM");

LFRtools.queue = {}; --guid
LFRtools.check = {}; --name

local settings = {};
local savedSettings = {
	enabled = true, -- Default: Yes normal processing
    announceLFR = true, -- Default: Announce to party/raid or only announce to player
	
}

local addonName, addonTable = ...

local function LoadSettings()
	settings = _G[addonName .. "DB"] or LFRtools.savedSettings
	_G[addonName .. "DB"] = settings
end

function LFRtools.onEvent(frame, event, arg, ...)
	if (event == "INSPECT_READY") then
		for i, guid in ipairs(LFRtools.queue) do
			if (arg == guid) then
				table.remove(LFRtools.queue, i);
				LFRtools.inspect(guid);
				ClearInspectPlayer();
				LFRtools.processQueue();
				return;
			end
		end
	elseif (event == "ROLE_CHANGED_INFORM") then
		local officer = ...;
		if (not UnitIsUnit(officer, "player")) then --If not done by yourself as officer
			LFRtools.enqueue(arg, false);
		end
	elseif (event == "UNIT_CONNECTION") then
		local connected = ...;
		if (connected) then
			LFRtools.enqueue(arg, false);
		end
	elseif (event == "PLAYER_SPECIALIZATION_CHANGED") then
		if (arg ~= nil) then
			LFRtools.enqueue(arg, false);
		end
	elseif (event == "GROUP_JOINED") or (event == "RAID_INSTANCE_WELCOME") then
		LFRtools.check = {};
		--LFRtools.scanGroup();
	elseif (event == "PARTY_LEADER_CHANGED") then
		if (UnitIsGroupLeader("player")) then
			LFRtools.scanGroup();
		end
	elseif (event == "READY_CHECK") then
		local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY");
		local msg = "";
		local raidRole = "";
		for i, name in ipairs(LFRtools.check) do
			if (UnitInParty(name) or UnitInRaid(name)) then
				raidRole = UnitGroupRolesAssigned(name);
				if (raidRole ~= "NONE") then
					msg = msg .. LFRtools.unitName(name) .. " (" .. LFRtools.roleName(raidRole) .. "), "
				end
			else
				table.remove(LFRtools.check, i);
			end
		end
		if (msg ~= "") then
			local message = "LFRtools: " .. msg .. "has/have an incorrect specialization!";
			if LFRtools.IsLookingForRaid() then
			    SendChatMessage(message, chatType);
			else
				print(message);
			end;
		end
	elseif (event == "PLAYER_ALIVE") then
		LFRtools.processQueue();
	elseif (event == "ADDON_LOADED") and (arg == "LFRtools") then
		LFRtools.frame:UnregisterEvent("ADDON_LOADED");
		DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Addon loaded");
		if (IsInGroup()) then
			LFRtools.scanGroup();
		end
	end
end

LFRtools.frame:SetScript("OnEvent", LFRtools.onEvent);

function LFRtools.inspect(guid)
	local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid);
	if (realm) and (realm ~= "") then
		name = name .. "-" .. realm;
	end
	local _, _, _, _, specRole, class = GetSpecializationInfoByID(GetInspectSpecialization(name));
	if (specRole == nil) then --Something went wrong.
		table.insert(LFRtools.queue, guid);
		return;
	end
	local raidRole = UnitGroupRolesAssigned(name);
	if (raidRole ~= specRole) and (not HasLFGRestrictions()) and (not InCombatLockdown()) and (UnitIsGroupLeader("player") or UnitIsRaidOfficer("player")) then
		UnitSetRole(name, specRole);
		return;
	end
	local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY");
	if (raidRole == "NONE") then
		return;
	elseif (raidRole ~= specRole) then
		for i, entry in ipairs(LFRtools.check) do
			if (name == entry) then
				return;
			end
		end
		table.insert(LFRtools.check, name);
		local message = "LFRtools: " .. LFRtools.unitName(name) .. " (" .. LFRtools.roleName(raidRole) .. ") is in " .. LFRtools.roleName(specRole) .. " specialization!";
		if LFRtools.IsLookingForRaid() then
			SendChatMessage( message, chatType);
		else
			print(message)
		end
	else
		for i, entry in ipairs(LFRtools.check) do
			if (name == entry) then
				local sex = UnitSex(name);
				local message = "LFRtools: " .. LFRtools.unitName(name) .. " (" .. LFRtools.roleName(raidRole) .. ") has corrected " .. (sex == 2 and "his" or (sex == 3 and "hers" or "its")) .. " specialization.";
				if LFRtools.IsLookingForRaid() then
				   SendChatMessage(message, chatType);
				else
					print(message);
				end;
				table.remove(LFRtools.check, i);
				return;
			end
		end
	end
end

function LFRtools.scanGroup()
	local unitType = IsInRaid() and "raid" or "party";
	for i = 1, GetNumGroupMembers() do
		LFRtools.enqueue(unitType .. i, false);
	end
end

function LFRtools.enqueue(unit, forced)
	local canBeTank, canBeHealer, canBeDPS = UnitGetAvailableRoles(unit);
	if (not canBeTank) and (not canBeHealer) and (canBeDPS) then
		local raidRole = UnitGroupRolesAssigned(unit);
		if (raidRole ~= "DAMAGER") and (not HasLFGRestrictions()) and (not InCombatLockdown()) and (UnitIsGroupLeader("player") or UnitIsRaidOfficer("player")) then
			UnitSetRole(unit, "DAMAGER");
		end
		return;
	end
	local guid = UnitGUID(unit);
	if (not forced) then
		for i, entry in ipairs(LFRtools.queue) do
			if (guid == entry) then
				return;
			end
		end
	end
	table.insert(LFRtools.queue, guid);
	if (not UnitIsDead("player")) and (not LFRtools.frame:GetScript("OnUpdate")) then
		LFRtools.processQueue();
	end
end

function LFRtools.unitName(unit)
	local name, realm = UnitName(unit);
	if (not realm) or (realm == "") then
		realm = GetRealmName();
	end
	return name .. "-" .. realm;
end

function LFRtools.roleName(role)
	return role == "DAMAGER" and "DPS" or role;
end

function LFRtools.onUpdate(frame, elapsed)
	LFRtools.total = LFRtools.total + elapsed;
	if (LFRtools.total >= 5) then --Timeout
		table.insert(LFRtools.queue, table.remove(LFRtools.queue, 1)); --Shuffle
		LFRtools.processQueue();
	end
end


 function LFRtools.IsLookingForRaid()
    local _, _, difficultyID, difficultyName = GetInstanceInfo()

    -- Check if the current difficulty matches LFR
    if
	difficultyID == 7 -- Legacy LFRs prior to SoO  
	or difficultyID == 17 -- Normal Looking For Raid
	or difficultyID == 24 -- Timewalking Party
	or difficultyID == 33 -- Timewalking Raid
	or difficultyID == 151 -- Timewalking Raid
	then
        print("You are in a Looking For Raid (LFR) instance.")
        return true
    else
        print("This is not an LFR instance.")
        return false
    end
end

function LFRtools.processQueue()
	if (#LFRtools.queue > 0) then
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queued " .. #LFRtools.queue);
		if (UnitIsDead("player")) then
			LFRtools.frame:SetScript("OnUpdate", nil);
			--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queue paused");
			return;
		end
		for i, guid in ipairs(LFRtools.queue) do
			local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid);
			if (name ~= nil) then
				if (realm) and (realm ~= "") then
					name = name .. "-" .. realm;
				end
				if (UnitIsConnected(name)) and (UnitInParty(name) or UnitInRaid(name)) then
					if (CanInspect(name)) then
						LFRtools.total = 0; --Reset timeout
						LFRtools.frame:SetScript("OnUpdate", LFRtools.onUpdate);
						NotifyInspect(name);
						return;
					end
				else
					table.remove(LFRtools.queue, i);
					LFRtools.processQueue();
					return;
				end
			end
		end
		LFRtools.total = 0; --Reset timeout
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: None of queued in range");
	else
		LFRtools.frame:SetScript("OnUpdate", nil);
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queue done");
	end
end
