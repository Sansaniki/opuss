--[[
	BagEquip — pune ghiozdanul pe spatele jucătorului.
	Script în ServerScriptService. Are nevoie de ReplicatedStorage.Bags (creat de BagBuilder).

	Ghiozdanul ales se setează cu un atribut pe Player:
	    player:SetAttribute("EquippedBag", "Explorer Pack")
	Se aplică imediat și la fiecare respawn. Implicit: "Wooden Basket".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bags = ReplicatedStorage:WaitForChild("Bags")
local DEFAULT_BAG = "Wooden Basket"

local function equip(character, bagName)
	local old = character:FindFirstChild("EquippedBag")
	if old then
		old:Destroy()
	end

	local template = Bags:FindFirstChild(bagName)
	if not template then
		warn("[BagEquip] Nu există ghiozdanul:", bagName)
		return
	end

	-- R15 are UpperTorso, R6 are Torso
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end

	local bag = template:Clone()
	bag.Name = "EquippedBag"
	bag:SetAttribute("BagName", bagName)

	for _, d in ipairs(bag:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end

	local handle = bag.PrimaryPart
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = handle
	-- fața -Z a ghiozdanului lipită de spatele trunchiului (+Z local al trunchiului)
	weld.C0 = CFrame.new(0, bag:GetAttribute("MountHeight") or 0, torso.Size.Z / 2 + handle.Size.Z / 2)
	weld.Parent = handle

	bag.Parent = character
end

local function onPlayer(player)
	if player:GetAttribute("EquippedBag") == nil then
		player:SetAttribute("EquippedBag", DEFAULT_BAG)
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		equip(character, player:GetAttribute("EquippedBag"))
	end)

	player:GetAttributeChangedSignal("EquippedBag"):Connect(function()
		if player.Character then
			equip(player.Character, player:GetAttribute("EquippedBag"))
		end
	end)

	if player.Character then
		equip(player.Character, player:GetAttribute("EquippedBag"))
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
