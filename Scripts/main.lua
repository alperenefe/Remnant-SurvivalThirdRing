local UEHelpers = nil
local function getUEHelpers()
 if not UEHelpers then UEHelpers = require("UEHelpers") end
 return UEHelpers
end
local function GetPlayerController()
 return getUEHelpers().GetPlayerController()
end
local function GetWorld()
 return getUEHelpers().GetWorld()
end

local MOD_PREFIX = "[SurvivalThirdRing] "
local MIN_RINGS_FOR_THIRD_SLOT = 1
local LOG_VERBOSE = false
local ENABLE_STAT_APPLY = true
local ENABLE_EQUIP_POST_HOOK = true
local LOG_EQUIP_HOOK = true
local LOG_DEBUG_STEPS = false

local ExtraRingItemID = 0
local ExtraRingItemBP = nil
local ExtraRingDisplayName = nil
local tickerStarted = false

if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 0 script loaded\n") end) end

local function log(msg)
 pcall(function()
 print(MOD_PREFIX .. tostring(msg) .. "\n")
 end)
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
 local out = nil
 pcall(function()
 logStep("CHAR", "getCharacter() start")
 local pc = GetPlayerController()
 if not pc or not pc:IsValid() then logStep("CHAR", "fail: no/invalid PlayerController"); return end
 local pawn = pc.Pawn
 if not pawn or not pawn:IsValid() then logStep("CHAR", "fail: no/invalid Pawn"); return end
 logStep("CHAR", "getCharacter() => ok")
 out = pawn
 end)
 return out
end

local function getInventory(char)
 local result = nil
 pcall(function()
 logStep("INV", "getInventory() start")
 local pc = GetPlayerController()
 if pc and pc:IsValid() then
 local getPlayerInv = pc.GetPlayerInventory
 if getPlayerInv then
 local inv = getPlayerInv(pc)
 if inv and inv:IsValid() then
 logStep("INV", "getInventory() => GetPlayerInventory(pc)")
 result = inv
 return
 end
 end
 end
 if not char or not char:IsValid() then
 logStep("INV", "fail: no char for fallbacks")
 return
 end
 local inv = char.Inventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.Inventory"); result = inv return end
 inv = char.InventoryComponent
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.InventoryComponent"); result = inv return end
 inv = char.PlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.PlayerInventory"); result = inv return end
 inv = char.RemnantPlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.RemnantPlayerInventory"); result = inv return end
 inv = char.MyInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => char.MyInventory"); result = inv return end
 if pc and pc:IsValid() then
 inv = pc.InventoryComponent
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.InventoryComponent"); result = inv return end
 inv = pc.PlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.PlayerInventory"); result = inv return end
 inv = pc.RemnantPlayerInventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.RemnantPlayerInventory"); result = inv return end
 inv = pc.Inventory
 if inv and inv:IsValid() then logStep("INV", "getInventory() => pc.Inventory"); result = inv return end
 end
 local comps = char.Components
 if comps and comps.Num then
 local ok, n = pcall(function() return comps:Num() end)
 if ok and n and n > 0 then
 for i = 0, n - 1 do
 local c = comps[i]
 if c and c:IsValid() and c.GetItems then
 logStep("INV", "getInventory() => Components[" .. tostring(i) .. "] (GetItems)")
 result = c
 return
 end
 end
 end
 end
 logStep("INV", "getInventory() => nil")
 end)
 return result
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

local function tryApplyThirdRingStats()
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step S1 stat apply start\n") end) end
 if not ENABLE_STAT_APPLY then return end
 local pc = GetPlayerController()
 if not pc or not pc:IsValid() then return end
 local pawn = pc.Pawn
 if not pawn or not pawn:IsValid() then return end
 local bp = ExtraRingItemBP
 if not bp or not bp:IsValid() then return end
 local char = getCharacter()
 if not char or not char:IsValid() then return end
 local statsComp = char.StatsComp or char.StatsComponent or char["StatsComp"] or char.StatComponent
 if not statsComp or not statsComp:IsValid() then
 local comps = char.Components
 if comps and comps.Num then
 local n = comps:Num()
 for i = 0, n - 1 do
 local c = comps[i]
 if c and c:IsValid() and c.ApplyStats then statsComp = c break end
 end
 end
 end
 if not statsComp or not statsComp:IsValid() then return end
 local invItem = nil
 pcall(function()
 local inv2 = getInventory(char)
 if inv2 and inv2:IsValid() and inv2.FindItemByID and ExtraRingItemID then
 invItem = inv2:FindItemByID(ExtraRingItemID)
 end
 end)
 local cdo = nil
 if bp.GetCDO then cdo = bp:GetCDO() end
 if not cdo or not cdo:IsValid() then return end
 local statRow = cdo.Stats or cdo.StatHandle or cdo.StatModifiers or cdo.InspectInfo
 if not statRow then
 if cdo.InspectInfo and cdo.InspectInfo.Stats then statRow = cdo.InspectInfo.Stats end
 if not statRow and cdo.DataTableRowHandle then statRow = cdo.DataTableRowHandle end
 end
 if not statRow then return end
 local function try(fn)
 return pcall(fn)
 end
 if statsComp.AddModifier then
 if invItem and try(function() statsComp:AddModifier(invItem) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:AddModifier(bp) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:AddModifier(statRow) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:AddModifier(bp, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 end
 if statsComp.ModifyStat then
 if invItem and try(function() statsComp:ModifyStat(invItem) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if invItem and try(function() statsComp:ModifyStat(invItem, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ModifyStat(bp) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ModifyStat(bp, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ModifyStat(statRow) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 end
 if statsComp.ApplyStats then
 if invItem and try(function() statsComp:ApplyStats(invItem, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if invItem and try(function() statsComp:ApplyStats(invItem, 1) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStats(bp, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStats(bp, 1) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStats(bp) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStats(statRow, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStats(statRow) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 local rn, dt = nil, nil
 pcall(function() rn = statRow.RowName dt = statRow.DataTable end)
 if rn and dt and dt.IsValid and dt:IsValid() then
 if try(function() statsComp:ApplyStats(dt, rn, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 local rnStr = nil
 pcall(function() if rn and rn.ToString then rnStr = rn:ToString() end end)
 if rnStr then
 if try(function() statsComp:ApplyStats(dt, rnStr, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if dt.FindRow then
 local rowData = nil
 pcall(function() rowData = dt:FindRow(rnStr) end)
 if rowData and try(function() statsComp:ApplyStats(rowData, 0) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 end
 end
 end
 if statsComp.ApplyStatModsTo then
 if try(function() statsComp:ApplyStatModsTo(statRow) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if try(function() statsComp:ApplyStatModsTo(bp) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 if invItem and try(function() statsComp:ApplyStatModsTo(invItem) end) then
 if statsComp.RecalculateStats then pcall(function() statsComp:RecalculateStats() end) end
 if statsComp.RefreshStats then pcall(function() statsComp:RefreshStats() end) end
 return
 end
 end
end

local TICKER_INTERVAL_MS = 3000

local function scheduleLabelRefresh()
 pcall(function()
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step T1 ticker run\n") end) end
 if ExtraRingDisplayName then
 local pc = GetPlayerController()
 local pawn = pc and pc:IsValid() and pc.Pawn
 if pawn and pawn:IsValid() then
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step T2 before refresh\n") end) end
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
 log("3rd label: Widget_Inventory_C not found (envanter kapalı veya farklı isim?)")
 return
 end
 local label = widget.ItemTypeLabel
 if not label or not label:IsValid() then
 log("3rd label: ItemTypeLabel yok veya geçersiz")
 return
 end
 label:SetText(FText("3rd: " .. ExtraRingDisplayName))
 log("3rd label: yazıldı -> 3rd: " .. tostring(ExtraRingDisplayName))
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
 pcall(tryApplyThirdRingStats)
 pcall(registerEquipStatHooks)
 if not tickerStarted and ExecuteWithDelay then
 tickerStarted = true
 ExecuteWithDelay(TICKER_INTERVAL_MS, scheduleLabelRefresh)
 end
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

local EQUIP_STAT_HOOK_PATHS = {
 "/Script/GunfireRuntime.InventoryComponent:EquipItem",
 "/Script/GunfireRuntime.InventoryComponent:EquipItemByID",
 "/Script/GunfireRuntime.InventoryComponent:UnequipItem",
 "/Script/Remnant.RemnantPlayerInventoryComponent:EquipItem",
 "/Script/Remnant.RemnantPlayerInventoryComponent:ClientEquipItem",
 "/Script/Remnant.RemnantPlayerInventoryComponent:ServerEquipItem",
 "/Script/Remnant.RemnantPlayerInventoryComponent:UnequipItem",
 "/Script/Remnant.RemnantPlayerInventoryComponent:OnRep_EquippedItems",
 "/Script/GunfireRuntime.StatsComponent:ApplyStats",
 "/Script/GunfireRuntime.StatsComponent:AddModifier",
 "/Script/GunfireRuntime.StatsComponent:RecalculateStats",
 "/Script/Remnant.RemnantPlayerController:RequestEquipItem",
 "/Script/Remnant.RemnantPlayerController:ClientEquipItem",
}
local equipStatHooksRegistered = false
local function registerEquipStatHooks()
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step H1 hook register start\n") end) end
 if not ENABLE_EQUIP_POST_HOOK or not RegisterHook or equipStatHooksRegistered then return end
 pcall(function()
 for _, path in ipairs(EQUIP_STAT_HOOK_PATHS) do
 pcall(function()
 RegisterHook(path, function(self, ...)
 if LOG_EQUIP_HOOK then
 log("[HOOK] " .. path)
 end
 if ExecuteWithDelay then
 ExecuteWithDelay(100, function()
 pcall(tryApplyThirdRingStats)
 end)
 end
 end)
 end)
 end
 equipStatHooksRegistered = true
 log("Equip/Stat post-hooks registered (" .. #EQUIP_STAT_HOOK_PATHS .. " paths). 3rd ring stats reapply on equip/stat.")
 end)
end

local function init()
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 1 init start\n") end) end
 RegisterKeyBind(Key.G, { ModifierKey.CONTROL }, function()
  log("[KEY] Ctrl+G: assignThirdRing")
  if ExecuteInGameThread then
   ExecuteInGameThread(function() safe(assignThirdRing) end)
  else
   safe(assignThirdRing)
  end
 end)
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 2 keybind G ok\n") end) end
 RegisterKeyBind(Key.Y, { ModifierKey.CONTROL }, function()
  log("[KEY] Ctrl+Y: clearThirdRing")
  if ExecuteInGameThread then
   ExecuteInGameThread(function() safe(clearThirdRing) end)
  else
   safe(clearThirdRing)
  end
 end)
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 3 keybind Y ok\n") end) end
 RegisterKeyBind(Key.F6, function()
  log("[KEY] F6: logThirdRingStatus")
  if ExecuteInGameThread then
   ExecuteInGameThread(function() safe(logThirdRingStatus) end)
  else
   safe(logThirdRingStatus)
  end
 end)
 if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 4 keybind F6 ok\n") end) end
 log("SurvivalThirdRing: keybinds registered (Ctrl+G, Ctrl+Y, F6).")
 if ExecuteWithDelay then
 ExecuteWithDelay(500, function()
 pcall(function()
 log("Loaded. Ctrl+G=assign 3rd ring, Ctrl+Y=clear, F6=status.")
 log("--- init done ---")
 end)
 end)
 end
end

if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 9 before deferred init\n") end) end
if ExecuteWithDelay then
 ExecuteWithDelay(15000, function()
  if ExecuteInGameThread then
   ExecuteInGameThread(function()
    pcall(function()
     log("SurvivalThirdRing: initializing (15s after load)...")
     init()
    end)
   end)
  else
   pcall(function()
    log("SurvivalThirdRing: initializing (15s after load)...")
    init()
   end)
  end
 end)
else
 safe(init)
end
if LOG_DEBUG_STEPS then pcall(function() print("[SurvivalThirdRing] step 10 deferred init scheduled\n") end) end
