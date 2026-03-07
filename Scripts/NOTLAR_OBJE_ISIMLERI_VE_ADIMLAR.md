# SurvivalThirdRing – Unutulmasın (Object / API / Adımlar)

Bu dosya ileride adım adım ekleme yaparken referans. GitLab sürümüne dönüldükten sonra bunların üzerine eklenecek.

---

## UE4SS Object Dump – Kesin path'ler

**Inventory (yüzük equip):**
- `/Script/GunfireRuntime.InventoryComponent:EquipItem`
- `/Script/GunfireRuntime.InventoryComponent:EquipItemByID`
- `/Script/GunfireRuntime.InventoryComponent:ServerEquipItemByID`
- `/Script/GunfireRuntime.InventoryComponent:ServerUnequipItemByID`
- `/Script/GunfireRuntime.InventoryComponent:UnequipItem`
- `/Script/GunfireRuntime.InventoryComponent:GetEquippedItem`
- Remnant alt sınıfı: `Remnant.RemnantPlayerInventoryComponent` aynı fonksiyonlara sahip.

**Stats:**
- `/Script/GunfireRuntime.StatsComponent:ApplyStats`
- `/Script/GunfireRuntime.StatsComponent:SetComputedStats`
- `/Script/GunfireRuntime.StatsComponent:GetComputedStats`
- `/Script/GunfireRuntime.StatsComponent:ModifyStat`
- `/Script/GunfireRuntime.StatsComponent:AddModifier`
- `/Script/GunfireRuntime.StatsComponent:RemoveModifier`
- `/Script/GunfireRuntime.StatsComponent:ApplyStatModsTo` (varsa denenecek)

---

## Stat uygulama – Ne yapıldı, ne yapılmayacak

**YAPMA (oyunu bozuyor):**
- `StatsComponent:SetComputedStats(statRow)` veya `(bp, 0)` – Tüm stat'ı eziyor, WASD/hasar bozuluyor.

**Denenecek (güvenli / ekleyici):**
- `ApplyStats(bp, 0)`, `ApplyStats(bp, 1)`, `ApplyStats(statRow, 0)`, `ApplyStats(invItem, 0)` vb.
- `ModifyStat(bp)`, `ModifyStat(statRow)`, `ModifyStat(invItem)` – modifier tarzı ekleme.
- `AddModifier(bp)`, `AddModifier(statRow)` – henüz denemedik, denenecek.
- `ApplyStatModsTo(statRow)` – dump'ta varsa denenecek.

**3. yüzük verisi:**
- ItemBP, CDO: `bp:GetCDO()`
- statRow: `cdo.Stats` / `cdo.StatHandle` / `cdo.StatModifiers` / `cdo.InspectInfo` / `cdo.InspectInfo.Stats` / `cdo.DataTableRowHandle`

---

## Crash / dikkat

- **ENABLE_STAT_APPLY = true** + ApplyStats/ModifyStat çağrıları – Oyun C++ tarafında patlayabilir; Lua pcall bunu durduramaz. Adım adım açılacak.
- **ENABLE_EQUIP_TRACE = true** + yüzlerce hook – Hook kaydı veya tetiklenme anında UE4SS/oyun patlayabilir. Önce az hook (sadece GunfireRuntime path'leri) veya kapalı gidilecek.

---

## Adım adım plan (GitLab sürümü üzerine)

1. GitLab'daki temiz sürüm buraya getir; sadece 3. yüzük atama + UI (Ctrl+G, Ctrl+Y, "3rd: X" label) çalışsın.
2. Obje isimleri / path'ler bu dosyadan alınacak; gerekirse hook veya stat kodu bu path'lerle yazılacak.
3. Stat: Önce sadece AddModifier / ApplyStatModsTo denemesi (SetComputedStats yok). Sonra gerekirse ModifyStat.
4. Equip tetikleme: İstenirse sadece GunfireRuntime.InventoryComponent path'leri ile az sayıda hook; veya ticker ile periyodik reapply.
5. Her büyük özellik (stat apply, equip hook) ayrı açılıp test; crash olursa hangi adımda olduğu belli olsun.

---

## Mod yapısı (referans)

- State: `ThirdRing = { ItemID, ItemBP, DisplayName }`, `pendingReapplyThirdRing`
- Init/keybind/ticker: `pcall` / `safe` / `safeInWorld` ile korunmalı
- tryApplyThirdRingStats: SetComputedStats kullanılmamalı; sadece ApplyStats/ModifyStat/AddModifier denemeleri
