package.path = package.path .. ";data/scripts/lib/?.lua;"
package.path = package.path .. ";data/scripts/?.lua;"

include ("stringutility")
include ("randomext")
include ("utility")
include ("faction")
include ("callable")
include ("reconstructionutility")
include ("gate_util")

local FactionsMap = include ("factionsmap")

local MAX_DISTANCE = 20

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerGateBuilder
PlayerGateBuilder = {}


local ui = {}
local data = {
	errMsg = "",
	errType = 2
}

function PlayerGateBuilder.interactionPossible(playerIndex, option)
    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return true, ""
    end

    return false
end

function PlayerGateBuilder.initialize()
	if Entity().title == "" then
		Entity().title = "Space Gate Builder"
	end

	if onClient() then
		if EntityIcon().icon == "" then
			EntityIcon().icon = "data/textures/icons/pixel/gate.png"
		end
	end
end

function PlayerGateBuilder.initUI()
	local res = getResolution()
    local size = vec2(480, 190)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Build Space Gate"%_t
    window.showCloseButton = 1
    window.moveable = 1
	
    menu:registerWindow(window, "Build Space Gate"%_t);

	local hSplit = UIHorizontalMultiSplitter(Rect(window.size), 0, 4, 3)
	local destVSplit = UIVerticalSplitter(hSplit:partition(0), 0, 12, 0.5)

    local xTextBox = window:createTextBox(destVSplit.left, "onNumberBoxChange")
    xTextBox.width = 180
    xTextBox.height = 30
    xTextBox.text = "0"
    xTextBox.allowedCharacters = "-0123456789"
    xTextBox.clearOnClick = 1
	ui.xInput = xTextBox

    local yTextBox = window:createTextBox(destVSplit.right, "onNumberBoxChange")
    yTextBox.width = 180
    yTextBox.height = 30
    yTextBox.text = "0"
    yTextBox.allowedCharacters = "-0123456789"
    yTextBox.clearOnClick = 1
	ui.yInput = yTextBox
	
	local infoVSplit = UIVerticalSplitter(hSplit:partition(1), 0, 12, 0.5)
	ui.distanceLabel = window:createLabel(infoVSplit.left, "Distance: 0.0", 14)
	window:createLabel(infoVSplit.right, string.format("Max distance %d", MAX_DISTANCE), 14)

	local checkVSplit = UIVerticalSplitter(hSplit:partition(2), 2, 12, 0.5)
	ui.errorLabel = window:createLabel(checkVSplit.right, "", 14)
	local color = Color()
	color:setHSV(0.0, 0.88, 0.80)
	ui.errorLabel.color = color
	ui.errorLabel:setLeftAligned()

    --Build Button
    local btnBuild = window:createButton(checkVSplit.left, "Build", "onBtnBuildClick")
    btnBuild.maxTextSize = 14
    btnBuild.width = 150
    btnBuild.height = 30
end

function __distance(x, y)
	local a, b = Sector():getCoordinates()
	return math.sqrt(math.pow(x - a, 2.0) + math.pow(y - b, 2.0))
end

function PlayerGateBuilder.onNumberBoxChange(box) 
	local x = tonumber(ui.xInput.text) or 0
	local y = tonumber(ui.yInput.text) or 0
	local dist = __distance(x, y)

	ui.distanceLabel.caption = string.format("Distance: %0.2f", dist)
	if dist <= MAX_DISTANCE then
		PlayerGateBuilder.info(string.format("Price: %s Cr", createMonetaryString(getPrice(dist))))
	else
		PlayerGateBuilder.error("Distance is too great")
	end
end

function PlayerGateBuilder.onBtnBuildClick(x, y)
	if onClient() then
		local x = tonumber(ui.xInput.text) or 0
		local y = tonumber(ui.yInput.text) or 0
		invokeServerFunction("onBtnBuildClick", x, y)

		return
	end

	local buyer, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end
	
	local dist = __distance(x, y)
	if dist > MAX_DISTANCE then
		PlayerGateBuilder.error("Distance is too great")
		return
	end

	if not Galaxy():sectorLoaded(x, y) then
		PlayerGateBuilder.warn("Sector is being loaded")
		Galaxy():loadSector(x, y)
		deferredCallback(1.0, "onBtnBuildClick", x, y)
		return
	end

	local sectorView = Galaxy():getSectorView(x, y)
	local factionsMap = FactionsMap(Server().seed)
	local relation = buyer:getRelation(sectorView.factionIndex)
	if not factionsMap:exists(sectorView.factionIndex) then
		PlayerGateBuilder.error("Can not target No Man's space")
		return
	elseif relation.level < 80000 and relation.status ~= RelationStatus.Allies then
		PlayerGateBuilder.error("Relations too low with target sector")
		return
	else
		local price = getPrice(dist)
		local canPay, msg, args = buyer:canPay(price)
		if not canPay then
			player:sendChatMessage(Entity(), 1, msg, unpack(args))
			return
		end

		buyer:pay("Paid %1% credits to build space gate"%_T, price)
		buildPlayerGates(x, y, buyer, player)
	end
end
callable(PlayerGateBuilder, "onBtnBuildClick")

function PlayerGateBuilder.info(msg)
	PlayerGateBuilder.showMsg(0, msg)
end
function PlayerGateBuilder.warn(msg)
	PlayerGateBuilder.showMsg(1, msg)
end
function PlayerGateBuilder.error(msg)
	PlayerGateBuilder.showMsg(2, msg)
end

function PlayerGateBuilder.showMsg(type, msg)
	data.errMsg = msg
	data.errType = type
	if onServer() then
		PlayerGateBuilder.sync()
	else
		PlayerGateBuilder.sync(data)
	end
end


function PlayerGateBuilder.sync(syncData)
	if onClient() then
		if not syncData then
			invokeServerFunction("sync")
		else
			data = syncData
			ui.errorLabel.caption = data.errMsg

			local color = Color()
			if data.errType == 0 then
				color:setHSV(130.0, 0.88, 0.80)
			elseif data.errType == 1 then
				color:setHSV(50.0, 0.88, 0.80)
			else
				color:setHSV(0.0, 0.88, 0.80)
			end
			ui.errorLabel.color = color
		end
	else
		invokeClientFunction(Player(callingPlayer), "sync", data)
	end
end
callable(PlayerGateBuilder, "sync")

function PlayerGateBuilder.restore(data)
	
end

function PlayerGateBuilder.secure()
    return {}
end

function getPrice(dist)
	return (15000.0 * math.pow(dist, 2.71828)) + (1000000.0 * dist)
end

function buildPlayerGates(x, y, buyer, player)
	local station = Entity()

	local position = station.position
	local factionIndex = station.factionIndex

	station:moveBy(vec3(0, 300, 0))

	-- Remove player from builder and delete it before spawning the gate
	if player.craftIndex == station.index then
        player.craftIndex = Uuid()
    end

	local name = station.name
	station.name = ""
	station:setPlan(BlockPlan())

	buyer:setShipDestroyed("", true)
	buyer:removeDestroyedShipInfo("")

	removeReconstructionKits(buyer, name)


	make_gate(x, y, position, factionIndex)

	local a, b = Sector():getCoordinates()
	code = [[
		function addGateBuilder(x, y, factionIndex)
			Sector():addScript("data/scripts/sector/generate_gate.lua", x, y, factionIndex)
		end
	]]
	runSectorCode(x, y, true, code, "addGateBuilder", a, b, factionIndex)
end

