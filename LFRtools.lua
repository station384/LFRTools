

local frame = CreateFrame("Frame", "LFRtools");


-- Make some local access to global functions just to speed things up a bit so it doesn't have to it the global space
-- Commenting these will not effect function of code,  it will just slow execution a bit
local ClearInspectPlayer = ClearInspectPlayer
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsUnit = UnitIsUnit
local IsInGroup = IsInGroup
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetSpecializationInfoByID=GetSpecializationInfoByID
local GetInspectSpecialization=GetInspectSpecialization
local InCombatLockdown=InCombatLockdown
local UnitIsRaidOfficer=UnitIsRaidOfficer
local UnitSetRole=UnitSetRole
local SendChatMessage=SendChatMessage
local GetNumGroupMembers=GetNumGroupMembers
local UnitGetAvailableRoles=UnitGetAvailableRoles
local HasLFGRestrictions=HasLFGRestrictions
local UnitName=UnitName
local GetRealmName=GetRealmName
local UnitIsDead=UnitIsDead
local UnitIsConnected=UnitIsConnected
local CanInspect=CanInspect
local NotifyInspect=NotifyInspect
local GetInstanceInfo=GetInstanceInfo
local UnitSex=UnitSex

local queue = {}; --guid
local check = {}; --name
local total = 0;
local settingID = nil;  --Used to hold the categoryID of the settings panel.
local settings = {};  --Volitile settings table
local savedSettings = {
	enabled = false, -- Default: Yes normal processing
    announceLFR = false, -- Default: Announce to party/raid or only announce to player
	
} -- Defaults for the settings if none exists.

local addonName, addonTable = ...

local function LoadSettings()
	settings = _G[addonName .. "DB"] or savedSettings
	_G[addonName .. "DB"] = settings
end



local function unitName(unit)
	local name, realm = UnitName(unit);
	if (not realm) or (realm == "") then
		realm = GetRealmName();
	end
	return name .. "-" .. realm;
end

local function roleName(role)
	return role == "DAMAGER" and "DPS" or role;
end



 local function IsLookingForRaid()
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



local function processQueue()
	--Note sure if I like this as an embeded function.   
	--But I believe LUA handles this like an anonoymous function which is faster than a call to a table(external class) and execution is faster since it is "local"
	local function onUpdate(frame, elapsed)
		total = total + elapsed;
		if (total >= 5) then --Timeout
			table.insert(queue, table.remove(queue, 1)); --Shuffle
			processQueue();
		end
	end

	if (#queue > 0) then
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queued " .. #LFRtools.queue);
		if (UnitIsDead("player")) then
			frame:SetScript("OnUpdate", nil);
			--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queue paused");
			return;
		end
		for i, guid in ipairs(queue) do
			local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid);
			if (name ~= nil) then
				if (realm) and (realm ~= "") then
					name = name .. "-" .. realm;
				end
				if (UnitIsConnected(name)) and (UnitInParty(name) or UnitInRaid(name)) then
					if (CanInspect(name)) then
						total = 0; --Reset timeout
						frame:SetScript("OnUpdate", onUpdate);
						NotifyInspect(name);
						return;
					end
				else
					table.remove(queue, i);
					processQueue();
					return;
				end
			end
		end
		total = 0; --Reset timeout
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: None of queued in range");
	else
		frame:SetScript("OnUpdate", nil);
		--DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Queue done");
	end
end

local function inspect(guid)
	if settings.enabled == false then -- were disabled.   Don't bother checking anything.
		return;
	end;
	local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid);
	if (realm) and (realm ~= "") then
		name = name .. "-" .. realm;
	end
	local _, _, _, _, specRole, class = GetSpecializationInfoByID(GetInspectSpecialization(name));
	if (specRole == nil) then --Something went wrong.
		table.insert(queue, guid);
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
		for i, entry in ipairs(check) do
			if (name == entry) then
				return;
			end
		end
		table.insert(check, name);
		local message = "LFRtools: " .. unitName(name) .. " (" .. roleName(raidRole) .. ") is in " .. roleName(specRole) .. " specialization!";

		if IsLookingForRaid() then 
			if settings.announceLFR == true then
				SendChatMessage( message, chatType);
				else
				print(message);
			end
		end


	else
		for i, entry in ipairs(check) do
			if (name == entry) then
				local sex = UnitSex(name);
				local message = "LFRtools: " .. unitName(name) .. " (" .. roleName(raidRole) .. ") has corrected " .. (sex == 2 and "his" or (sex == 3 and "hers" or "its")) .. " specialization.";
				if IsLookingForRaid() then
					if settings.announceLFR == true then
						SendChatMessage(message, chatType);
					else
						print(message);
					end;
				end;
				table.remove(check, i);
				return;
			end
		end
	end
end

local function enqueue(unit, forced)
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
		for i, entry in ipairs(queue) do
			if (guid == entry) then
				return;
			end
		end
	end
	table.insert(queue, guid);
	if (not UnitIsDead("player")) and (not frame:GetScript("OnUpdate")) then
		processQueue();
	end
end

local function scanGroup()
	local unitType = IsInRaid() and "raid" or "party";
	for i = 1, GetNumGroupMembers() do
		enqueue(unitType .. i, false);
	end
end



-- Create Options Panel
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", addonName .. "OptionsPanel", UIParent)
    panel.name = addonName

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LFR Tools Settings")

	-- Checkbox LFRtools Enabled
	local cbEnabled = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	cbEnabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	cbEnabled.Text:SetText("Enabled")
	cbEnabled:SetChecked(settings.enabled)

	cbEnabled:SetScript("OnClick", function(self)
		settings.enabled = self:GetChecked()
		_G[addonName .. "DB"].enabled = settings.enabled -- Sync with SavedVariables
		--print("LFRtools enabled set to:", settings.enabled)
	end)

    -- Checkbox LFR Announce
    local cbLFRAnnounce = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbLFRAnnounce:SetPoint("TOPLEFT", cbEnabled, "BOTTOMLEFT", 0, -10)
    cbLFRAnnounce.Text:SetText("Announce detection to party")
    cbLFRAnnounce:SetChecked(settings.announceLFR)
	cbLFRAnnounce:SetScript("OnClick", function(self)
		settings.announceLFR = self:GetChecked()
		_G[addonName .. "DB"].announceLFR = settings.announceLFR -- Sync with SavedVariables
		--print("Announce LFR set to:", settings.announceLFR)
	end)
	
  
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
	settingID = category:GetID();
end


local function onEvent(frame, event, arg, ...)
	--elseif trashes the stack.   so bring it back to short circuting ifs.   
	if (event == "INSPECT_READY") then
		for i, guid in ipairs(queue) do
			if (arg == guid) then
				table.remove(queue, i);
				inspect(guid);
				ClearInspectPlayer();
				processQueue();
				return;
			end
		end
		return;
	end;

	if (event == "ROLE_CHANGED_INFORM") then
		local officer = ...;
		if (not UnitIsUnit(officer, "player")) then --If not done by yourself as officer
			enqueue(arg, false);
		end
		return;
	end;

	if (event == "UNIT_CONNECTION") then
		local connected = ...;
		if (connected) then
			enqueue(arg, false);
		end
	  return;
	end;

	if (event == "PLAYER_SPECIALIZATION_CHANGED") then
		if (arg ~= nil) then
			enqueue(arg, false);
		end
		return;
	end;
	
	if (event == "GROUP_JOINED") or (event == "RAID_INSTANCE_WELCOME") then
		check = {};
		--scanGroup();
		return;
	end;

	if (event == "PARTY_LEADER_CHANGED") then
		if (UnitIsGroupLeader("player")) then
			scanGroup();
		end
		return;
	end;
	
	if (event == "READY_CHECK") then
		local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY");
		local msg = "";
		local raidRole = "";
		for i, name in ipairs(check) do
			if (UnitInParty(name) or UnitInRaid(name)) then
				raidRole = UnitGroupRolesAssigned(name);
				if (raidRole ~= "NONE") then
					msg = msg .. unitName(name) .. " (" .. roleName(raidRole) .. "), "
				end
			else
				table.remove(check, i);
			end
		end
		if (msg ~= "") then
			local message = "LFRtools: " .. msg .. "has/have an incorrect specialization!";
			if IsLookingForRaid() then
				if settings.announceLFR == true then
					SendChatMessage(message, chatType);
				else
					print(message);
				end;
			end;
		end
		return;
	end;

	if (event == "PLAYER_ALIVE") then
		processQueue();
		return;
	end;

	if (event == "ADDON_LOADED") and (arg == addonName) then
		frame:UnregisterEvent("ADDON_LOADED");

			LoadSettings()
			CreateOptionsPanel()

			DEFAULT_CHAT_FRAME:AddMessage("LFRtools: Addon loaded");
		
		if (IsInGroup()) then
			scanGroup();
		end
		return;
	end;

end

local function boolToString(boolVal)
if type(boolVal) == "boolean" then
	if (boolVal == true) then
		return "Yes";
	else
		return "No";
	end
else
	return"Not Boolean value";
end

end
local function PrintAddonInfo()
    print ("LFRTools-Name:" .. addonName .. "-Enabled:" .. boolToString(settings.enabled) .. "-announceLFR:" .. boolToString(settings.announceLFR) );
end

--For backwards compatability to the original Addon incase anyone was using the scanGroup in a macro
LFRtools = {
	scanGroup = scanGroup,
	printName = PrintAddonInfo
};

frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("INSPECT_READY");
frame:RegisterEvent("PLAYER_ALIVE");
frame:RegisterEvent("READY_CHECK");
--Group scan
frame:RegisterEvent("RAID_INSTANCE_WELCOME");
frame:RegisterEvent("GROUP_JOINED");
frame:RegisterEvent("PARTY_LEADER_CHANGED");
--Member scan
--LFRtools.frame:RegisterEvent("UNIT_CONNECTION");
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
frame:RegisterEvent("ROLE_CHANGED_INFORM");
frame:SetScript("OnEvent", onEvent);

-- Slash Commands for Addon
SLASH_LFRTOOLS1 = "/LFRTOOLS"
SLASH_LFRTOOLS2 = "/LFRT"
SlashCmdList["LFRTOOLS"] = function(msg)
    local command = string.lower(msg)
	if command == "" or command == "open" then
		print (settingID);
        Settings.OpenToCategory(settingID)
    elseif command == "checklfr" then
        IsLookingForRaid()
	elseif command == "help" then
        print("Usage: /LFRtools open - Open the settings panel")
        print("Usage: /LFRtools checklfr - Check if in LFR")
    end
end

-- SLASH_LFRTOOLSSETTINGS1 = "/lfrsettings"
-- SlashCmdList["LFRTOOLSSETTINGS"] = function()
--     print("Enabled:", settings.enabled)
--     print("Announce LFR:", settings.announceLFR)
-- end