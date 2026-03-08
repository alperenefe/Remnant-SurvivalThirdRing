# 3. Yüzük Stat Apply – Denenenler (tekrar deneme)

**Amaç:** 3. slotta atadığımız yüzüğün stat’larının oyunda gerçekten uygulanması (şu an sadece UI’da "3rd: X" görünüyor, karaktere stat gelmiyor).

**Durum:** Aşağıdaki tüm denemeler yapıldı, hepsi FAIL veya etkisiz. İleride yeni fikir denenecekse bu listeye bakıp tekrar denemeyelim.

---

## StatsComp üzerinden

- `statsComp:SetComputedStats(statRow)` / `(statRow, 0)` / `(bp, 0)` / `(invItem, 0)` — F7'de görünen tek isim. **UYARI:** Bu fonksiyon tüm computed stat'ı tek row ile DEĞİŞTİRİYOR (eklemiyor); %25 damage vb. sıfırlanıyor, WASD bozulabiliyor. Modda ENABLE_STAT_APPLY=false ile stat apply kapatıldı.
- `statsComp:ApplyStats(statRow, 0)`
- `statsComp:ApplyStats(dt, rn, 0)` — DataTable + RowName
- `statsComp:ApplyStats(dt, rnStr, 0)` — RowName string
- `statsComp:ApplyStats(dt, FName(rnStr), 0)` — RowName FName
- `statsComp:ApplyStats(rowData, 0)` / `(rowData, 1)` — DataTable FindRow ile bulunan row
- `statsComp:ApplyStats(bp, 0)` — ItemBP doğrudan
- `statsComp:ApplyStats(invItem, 0)` / `(invItem, 1)` — envanter item instance (FindItemByID sonucu), BP değil
- `statsComp:ApplyStats(statRow)` — tek argüman
- `statsComp:ApplyStats(statRow, 1)` / `(statRow, 10)` — farklı 2. parametre
- `ExecuteInGameThread` içinde `statsComp:ApplyStats(statRow, 0)`

## StatsComp alternatif fonksiyon isimleri

(ApplyStatsFromItem, AddStatModifier, ApplyItemStats, AddStatsFromItem, ApplyStatModifiers, AddStats, ApplyTrinketStats, RefreshStats, RecalculateStats, UpdateStats)

- `StatsComp.<name>(statRow, 0)`
- `StatsComp.<name>(bp, 0)`
- `StatsComp.<name>(statRow)`

## Inventory üzerinden

- `inv.<altName>(bp)` / `inv.<altName>(statRow, 0)` — aynı alt isimlerle

## Character üzerinden

- `char.ApplyStats(statRow, 0)` / `char.RefreshStats(statRow, 0)` / `char.RecalculateStats(statRow, 0)`

## ProcessEvent (UFunction)

- `StaticFindObject("/Script/Engine.StatsComponent:ApplyStats")` → `ProcessEvent(ufn, { statRow, 0 })`
- StatsComp’un gerçek class adı ile `StaticFindObject(className .. ":ApplyStats")` → `ProcessEvent(ufn, { statRow, 0 })` ve `{ bp, 0 }`

## Inventory equip / notify

- `inv:EquipItem(Trinket3Slot, item)` / `inv:EquipItem("Trinket3", item)`
- `inv:EquipItemInSlot(...)`, `SetEquippedItem`, `EquipItemToSlot`, `ApplyItemStats`, `AddItemStats`, `OnItemEquipped`, `NotifyItemEquipped` — Trinket3 + item veya sadece item

---

## Stat verisi nereden alındı

- 3. yüzük ItemBP’nin CDO’su: `bp:GetCDO()`
- statRow: `cdo.Stats` / `cdo.StatHandle` / `cdo.StatModifiers` / `cdo.InspectInfo` / `cdo.InspectInfo.Stats` / `cdo.DataTableRowHandle`

---

## İleride denenecek fikirler (henüz yapılmadı)

- Oyunun kendi “equip trinket” akışını (slot 1/2 takarken ne çağrılıyor) trace etmek (log veya başka mod).
- Trinket3 diye bir slot FName’i oyunda var mı, yoksa sadece “fake” UI slot mu araştırmak.
- Başka bir Remnant modunda trinket/stat uygulama örneği var mı bakmak.

---

## Post-hook (main.lua'da eklendi)

- `ENABLE_EQUIP_POST_HOOK = true`: Oyunun equip/stat çağırdığı fonksiyonlara RegisterHook ile post-process eklenir. Hook tetiklenince 100ms sonra `tryApplyThirdRingStats()` çağrılır; böylece 3. yüzük stat'ı, slot 1/2 güncellendiğinde de yeniden uygulanır.
- Hook path'leri: `InventoryComponent:EquipItem`, `EquipItemByID`, `RemnantPlayerInventoryComponent:EquipItem`, `ClientEquipItem`, `StatsComponent:ApplyStats`, `AddModifier`, `RecalculateStats`.
- Hangi path'in gerçekten tetiklendiğini görmek için `LOG_EQUIP_HOOK = true` yap; yüzük takıp çıkarınca log'da `[HOOK] path` satırları çıkar.
