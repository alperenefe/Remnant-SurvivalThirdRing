local UEHelpers = require("UEHelpers")
local GetPlayerController = UEHelpers.GetPlayerController
local GetWorld = UEHelpers.GetWorld

local MOD_PREFIX = "[SurvivalThirdRing] "
local MIN_RINGS_FOR_THIRD_SLOT = 1
local LOG_VERBOSE = true

local ExtraRingItemID = 0
local ExtraRingItemBP = nil
local ExtraRingDisplayName = nil

local function log(msg)
 print(MOD_PREFIX .. msg .. "\n")
end

local function logStep(tag, msg)
 if LOG_VERBOSE then
 log("[" .. tag .. "] " .. msg)
 end
end

local function safe(fn)
 local ok, err = pcall(fn)
 if not ok then
 log("Error: " .. tostring(err))
 return nil
 end
 return true
end

local function getCharacter()
 logStep("CHAR", "getCharacter() start")
 local pc = GetPlayerController()
 if not pc or not pc:IsValid() then
 logStep("CHAR", "fail: no/invalid PlayerController")
 return nil
 end
 local pawn = pc.Pawn
 if not pawn or not pawn:IsValid() then
 logStep("CHAR", "fail: no/invalid Pawn")
 return nil
 end
 logStep("CHAR", "getCharacter() => ok")
 return pawn
end

local function getInventory(char)
 logStep("INV", "getInventory() start")
 local pc = GetPlayerController()
 if pc and pc:IsValid() then
 local getPlayerInv = pc.GetPlayerInventory
 if getPlayerInv then
 local inv = getPlayerInv(pc)
 if inv and inv:IsValid() then
 logStep("INV", "getInventory() => GetPlayerInventory(pc)")
 return inv
 end
 end
 end
 if not char or not char:IsValid() then
 logStep("INV", "fail: no char for fallbacks")
 return nil
 end
 local inv = char.Inventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.Inventory") return inv end
 inv = char.InventoryComponent
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.InventoryComponent") return inv end
 inv = char.PlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.PlayerInventory") return inv end
 inv = char.RemnantPlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.RemnantPlayerInventory") return inv end
 inv = char.MyInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.MyInventory") return inv end
 if pc and pc:IsValid() then
 inv = pc.InventoryComponent
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.InventoryComponent") return inv end
 inv = pc.PlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.PlayerInventory") return inv end
 inv = pc.RemnantPlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.RemnantPlayerInventory") return inv end
 inv = pc.Inventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.Inventory") return inv end
 end
 local comps = char.Components
 if comps and comps.Num then
 local ok, n = pcall(function() return comps:Num() end)
 if ok and n and n > 0 then
 for i = 0, n - 1 do
 local c = comps[i]
 if c and c:IsValid() and c.GetItems then
 logStep("INV", "getInventory() => Components[" .. tostring(i) .. "] (GetItems)")
 return c
 end
 end
 end
 end
 logStep("INV", "getInventory() => nil")
 return nil
end

local function isRingItem(item)
 if not item then return false end
 local bp = item.ItemBP
 if not bp or not bp:IsValid() then return false end
 local name = nil
 if bp.GetFullName then name = bp:GetFullName() end
 if not name and bp.GetName then name = bp:GetName() end
 if not name then return true end
 if string.find(name, "Amulet") or string.find(name, "Neck") then return false end
 return true
end

local function getRingDisplayNameFromBP(bp)
 if not bp or not bp:IsValid() then return "?" end
 local raw = nil
 if bp.GetFullName then raw = bp:GetFullName() end
 if not raw or raw == "" then
 if bp.GetName then raw = bp:GetName() end
 end
 if not raw or raw == "" then return "?" end
 local short = raw:match("(Trinket_[%w_]+_C)") or raw:match("([^/]+)_C") or raw:match("^([^%s/]+)") or raw
 short = short:gsub("_C$", ""):gsub("^Trinket_", ""):gsub("_", " ")
 return #short > 0 and short or "?"
end

local function getEquippedInSlot(inv, slotName)
 if not inv or not inv:IsValid() then return nil end
 local findFn = inv.FindItemByEquipSlotNameID
 if not findFn then
 logStep("SLOT", "getEquippedInSlot(" .. tostring(slotName) .. ") no FindItemByEquipSlotNameID")
 return nil
 end
 for _, name in ipairs({ slotName, slotName .. "Slot" }) do
 local fname = FName(name, EFindName.FNAME_Find)
 if fname == NAME_None then fname = FName(name, EFindName.FNAME_Add) end
 local item = findFn(inv, fname)
 if item then
 logStep("SLOT", "getEquippedInSlot(" .. tostring(slotName) .. ") => " .. tostring(name))
 return item
 end
 end
 logStep("SLOT", "getEquippedInSlot(" .. tostring(slotName) .. ") => nil")
 return nil
end

local function getUniqueRingCount(inv)
 if not inv or not inv:IsValid() then
 logStep("RINGS", "getUniqueRingCount: no inv => 0")
 return 0
 end
 local seen = {}
 local count = 0
 local t1 = getEquippedInSlot(inv, "Trinket1")
 local t2 = getEquippedInSlot(inv, "Trinket2")
 if t1 and t1.ItemBP and t1.ItemBP:IsValid() and isRingItem(t1) then
 local key = t1.ItemBP.GetFullName and t1.ItemBP:GetFullName() or nil
 if key and not seen[key] then seen[key] = true count = count + 1 end
 end
 if t2 and t2.ItemBP and t2.ItemBP:IsValid() and isRingItem(t2) then
 local key = t2.ItemBP.GetFullName and t2.ItemBP:GetFullName() or nil
 if key and not seen[key] then seen[key] = true count = count + 1 end
 end
 local getItems = inv.GetItems
 if not getItems then
 logStep("RINGS", "getUniqueRingCount: no GetItems => " .. tostring(count))
 return count
 end
 local items = getItems(inv)
 if not items then
 logStep("RINGS", "getUniqueRingCount: GetItems() nil => " .. tostring(count))
 return count
 end
 local len = 0
 if items.Num then len = items:Num() end
 logStep("RINGS", "getUniqueRingCount: inv items count=" .. tostring(len))
 for i = 0, len - 1 do
 local entry = items[i]
 if entry and entry.ItemBP and entry.ItemBP:IsValid() then
 local key = entry.ItemBP.GetFullName and entry.ItemBP:GetFullName() or nil
 if key and not seen[key] and isRingItem(entry) then
 seen[key] = true
 count = count + 1
 end
 end
 end
 if count == 0 and len == 0 then
 logStep("RINGS", "getUniqueRingCount: len was 0, trying 1..500")
 for j = 1, 500 do
 local entry = items[j]
 if not entry then break end
 if entry.ItemBP and entry.ItemBP:IsValid() then
 local key = entry.ItemBP.GetFullName and entry.ItemBP:GetFullName() or nil
 if key and not seen[key] and isRingItem(entry) then
 seen[key] = true
 count = count + 1
 end
 end
 end
 end
 logStep("RINGS", "getUniqueRingCount => " .. tostring(count))
 return count
end

local function isEquippedInSlot1Or2(inv, itemID)
 if not itemID or itemID == 0 then return false end
 local t1 = getEquippedInSlot(inv, "Trinket1")
 local t2 = getEquippedInSlot(inv, "Trinket2")
 if t1 and t1.ItemID == itemID then return true end
 if t2 and t2.ItemID == itemID then return true end
 return false
end

local function sameBP(a, b)
 if not a or not a:IsValid() or not b or not b:IsValid() then return false end
 local na, nb = nil, nil
 if a.GetFullName then na = a:GetFullName() end
 if b.GetFullName then nb = b:GetFullName() end
 if not na or not nb then return a == b end
 return na == nb
end

local function isEquippedInSlot1Or2ByItem(inv, item)
 if not inv or not inv:IsValid() or not item or not item.ItemBP then return false end
 local t1 = getEquippedInSlot(inv, "Trinket1")
 local t2 = getEquippedInSlot(inv, "Trinket2")
 if t1 and t1.ItemBP and sameBP(item.ItemBP, t1.ItemBP) then return true end
 if t2 and t2.ItemBP and sameBP(item.ItemBP, t2.ItemBP) then return true end
 return false
end

local function isThirdRingNowInSlot1Or2(inv)
 if not ExtraRingItemBP or not ExtraRingItemBP:IsValid() or not inv or not inv:IsValid() then return false end
 local t1 = getEquippedInSlot(inv, "Trinket1")
 local t2 = getEquippedInSlot(inv, "Trinket2")
 if t1 and t1.ItemBP and sameBP(ExtraRingItemBP, t1.ItemBP) then return true end
 if t2 and t2.ItemBP and sameBP(ExtraRingItemBP, t2.ItemBP) then return true end
 return false
end

local function hasItemByID(inv, itemID)
 if not inv or not inv:IsValid() or not itemID or itemID == 0 then return false end
 local findFn = inv.FindItemByID
 if not findFn then return false end
 local item = findFn(inv, itemID)
 return item ~= nil
end

local function getSelectedInventoryItem()
 logStep("SEL", "getSelectedInventoryItem() start")
 local widget = FindFirstOf("Widget_Inventory_C")
 if not widget or not widget:IsValid() then
 logStep("SEL", "no Widget_Inventory_C")
 return nil
 end
 local sel = widget.SelectedItemID
 if not sel then sel = widget.SelectedItem end
 logStep("SEL", "SelectedItemID/SelectedItem => " .. tostring(sel))
 return sel
end

local function getThirdRingDisplayName()
 if not ExtraRingItemBP or not ExtraRingItemBP:IsValid() then return nil end
 return getRingDisplayNameFromBP(ExtraRingItemBP)
end

local function refreshLabelOnly()
 if not ExtraRingDisplayName then return end
 pcall(function()
 local widget = FindFirstOf("Widget_Inventory_C")
 if not widget or not widget:IsValid() then return end
 local label = widget.ItemTypeLabel
 if not label or not label:IsValid() then return end
 label:SetText(FText("3rd: " .. ExtraRingDisplayName))
 end)
end

local TICKER_INTERVAL_MS = 3000

local function scheduleLabelRefresh()
 pcall(function()
 if ExtraRingDisplayName then
 local pc = GetPlayerController()
 local pawn = pc and pc:IsValid() and pc.Pawn
 if pawn and pawn:IsValid() then
 refreshLabelOnly()
 end
 end
 end)
 pcall(function()
 if ExecuteWithDelay then
 ExecuteWithDelay(TICKER_INTERVAL_MS, scheduleLabelRefresh)
 end
 end)
end

local SYNC_INTERVAL_MS = 2500

local function syncThirdRingIfMoved()
 pcall(function()
 if not ExtraRingDisplayName then return end
 local char = getCharacter()
 local inv = char and getInventory(char)
 if not inv or not inv:IsValid() then return end
 if not isThirdRingNowInSlot1Or2(inv) then return end
 ExtraRingItemID = 0
 ExtraRingItemBP = nil
 ExtraRingDisplayName = nil
 logStep("SYNC", "3rd ring moved to slot 1/2, auto-cleared")
 local widget = FindFirstOf("Widget_Inventory_C")
 if widget and widget:IsValid() then
 local label = widget.ItemTypeLabel
 if label and label:IsValid() then
 label:SetText(FText("Trinket"))
 end
 end
 end)
end

local function updateInventoryLabel()
 logStep("UI", "updateInventoryLabel() start, ExtraRingDisplayName=" .. tostring(ExtraRingDisplayName))
 if not ExtraRingDisplayName then return end
 local ok1, err1 = pcall(function()
 local char = getCharacter()
 local inv = char and getInventory(char)
 if inv and inv:IsValid() and isThirdRingNowInSlot1Or2(inv) then
 ExtraRingItemID = 0
 ExtraRingItemBP = nil
 ExtraRingDisplayName = nil
 logStep("UI", "updateInventoryLabel: 3rd ring moved to slot 1/2, cleared")
 end
 if not ExtraRingDisplayName then
 local widget = FindFirstOf("Widget_Inventory_C")
 if widget and widget:IsValid() then
 local label = widget.ItemTypeLabel
 if label and label:IsValid() then
 label:SetText(FText("Trinket"))
 end
 end
 return
 end
 local widget = FindFirstOf("Widget_Inventory_C")
 if not widget or not widget:IsValid() then
 logStep("UI", "updateInventoryLabel: no widget")
 return
 end
 local label = widget.ItemTypeLabel
 if not label or not label:IsValid() then
 logStep("UI", "updateInventoryLabel: no ItemTypeLabel")
 return
 end
 label:SetText(FText("3rd: " .. ExtraRingDisplayName))
 logStep("UI", "updateInventoryLabel: SetText ok")
 end)
 if not ok1 then
 log("updateInventoryLabel error: " .. tostring(err1))
 end
end

local function assignThirdRing()
 log("--- assignThirdRing (Ctrl+G) ---")
 logStep("ASSIGN", "getCharacter()")
 local char = getCharacter()
 logStep("ASSIGN", "getInventory(char)")
 local inv = getInventory(char)
 if not inv then
 log("No inventory")
 return
 end
 if isThirdRingNowInSlot1Or2(inv) then
 ExtraRingItemID = 0
 ExtraRingItemBP = nil
 ExtraRingDisplayName = nil
 logStep("ASSIGN", "3rd ring was moved to slot 1/2, cleared")
 end
 logStep("ASSIGN", "getUniqueRingCount(inv)")
 local ringCount = getUniqueRingCount(inv)
 log("Ring count: " .. tostring(ringCount))
 logStep("ASSIGN", "getSelectedInventoryItem()")
 local selected = getSelectedInventoryItem()
 local itemID = selected
 if type(selected) == "userdata" then
 if selected and selected.ItemID then itemID = selected.ItemID end
 end
 log("Selected itemID: " .. tostring(itemID))
 if ringCount < MIN_RINGS_FOR_THIRD_SLOT then
 log("Need at least " .. tostring(MIN_RINGS_FOR_THIRD_SLOT) .. " different rings (you have " .. tostring(ringCount) .. ")")
 return
 end
 if not itemID or itemID == 0 then
 log("Select a ring in inventory first (click on it in Trinket list)")
 return
 end
 logStep("ASSIGN", "FindItemByID")
 local findFn = inv.FindItemByID
 if not findFn then
 log("FindItemByID not found")
 return
 end
 local item = findFn(inv, itemID)
 if not item then
 log("Selected item not in inventory")
 return
 end
 logStep("ASSIGN", "isRingItem(item)")
 if not isRingItem(item) then
 log("Selected item is not a ring")
 return
 end
 logStep("ASSIGN", "isEquippedInSlot1Or2")
 if isEquippedInSlot1Or2(inv, itemID) then
 log("Already equipped in slot 1 or 2")
 return
 end
 if isEquippedInSlot1Or2ByItem(inv, item) then
 log("This ring is already equipped in slot 1 or 2 (same type)")
 return
 end
 logStep("ASSIGN", "set ExtraRingItemID/ItemBP/DisplayName")
 ExtraRingItemID = itemID
 ExtraRingItemBP = item.ItemBP
 ExtraRingDisplayName = nil
 local okCdo, cdoLabel = pcall(function()
 if not item.ItemBP or not item.ItemBP:IsValid() then return nil end
 local getCdo = item.ItemBP.GetCDO
 if not getCdo then return nil end
 local cdo = getCdo(item.ItemBP)
 if not cdo or not cdo:IsValid() or not cdo.Label then return nil end
 local lbl = cdo.Label
 if type(lbl) == "string" then return lbl end
 if type(lbl) == "userdata" and lbl.ToString and type(lbl.ToString) == "function" then
 return lbl:ToString()
 end
 return tostring(lbl)
 end)
 if okCdo and cdoLabel and type(cdoLabel) == "string" and #cdoLabel > 0 then
 ExtraRingDisplayName = cdoLabel
 end
 if not ExtraRingDisplayName or ExtraRingDisplayName == "" then
 ExtraRingDisplayName = getRingDisplayNameFromBP(item.ItemBP)
 end
 if ExtraRingDisplayName == "" then ExtraRingDisplayName = "?" end
 log("3rd ring assigned: " .. tostring(ExtraRingDisplayName))
 logStep("ASSIGN", "updateInventoryLabel()")
 updateInventoryLabel()
 log("--- assignThirdRing done ---")
end

local function clearThirdRing()
 log("--- clearThirdRing (Ctrl+Y) ---")
 ExtraRingItemID = 0
 ExtraRingItemBP = nil
 ExtraRingDisplayName = nil
 log("3rd ring cleared")
 updateInventoryLabel()
 log("--- clearThirdRing done ---")
end

local function logThirdRingStatus()
 log("--- logThirdRingStatus (F6) ---")
 if ExtraRingDisplayName then
 log("3rd ring: " .. ExtraRingDisplayName .. " (ItemID " .. tostring(ExtraRingItemID) .. ")")
 else
 log("3rd ring: (none)")
 end
 log("--- F6 done ---")
end

local function init()
 RegisterKeyBind(Key.G, { ModifierKey.CONTROL }, function()
 log("[KEY] Ctrl+G: assignThirdRing")
 safe(assignThirdRing)
 end)
 RegisterKeyBind(Key.Y, { ModifierKey.CONTROL }, function()
 log("[KEY] Ctrl+Y: clearThirdRing")
 safe(clearThirdRing)
 end)
 RegisterKeyBind(Key.F6, function()
 log("[KEY] F6: logThirdRingStatus")
 safe(logThirdRingStatus)
 end)
 log("Loaded. Ctrl+G=assign 3rd ring, Ctrl+Y=clear, F6=status. LOG_VERBOSE=" .. tostring(LOG_VERBOSE))
 if ExecuteWithDelay then
 ExecuteWithDelay(TICKER_INTERVAL_MS, scheduleLabelRefresh)
 end
 log("--- init done ---")
end

safe(init)
