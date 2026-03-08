# Somut crash senaryoları – teyit rehberi

Aşağıdaki her madde: **Tam şu anda şu kod çalışırsa patlar** + **Nasıl teyit edersin**.

---

## 1. Ticker tam loading sırasında – FindAllOf / Pawn

**Ne zaman:** Mod yüklendikten tam **3 saniye** sonra `scheduleLabelRefresh` çalışıyor. Sen ana menüde "Play Game"e tıkladın, 1–3 saniye içinde loading ekranındayken bu ticker tetikleniyor.

**Hangi kod:** `main.lua` → `scheduleLabelRefresh()` (satır 461) → `GetPlayerController()` → `UEHelpers.lua` satır 35–40: `FindAllOf("PlayerController")` veya `FindAllOf("Controller")`, sonra `Controller.Pawn` ve `Controller.Pawn:IsValid()`.

**Neden patlar:** Dünya henüz yok veya yıkılıyor; FindAllOf veya dönen controller/pawn native tarafta geçersiz. Lua `pcall` sadece Lua hatalarını yakalar, **native crash’i durdurmaz**.

**Teyit:**  
- `main.lua` içinde ilk ticker’ı geciktir: `ExecuteWithDelay(TICKER_INTERVAL_MS, ...)` yerine ilk seferde `ExecuteWithDelay(15000, scheduleLabelRefresh)` kullan (15 sn).  
- Oyunu aç, **hemen** Play Game’e bas, 15 saniye beklemeden devam et.  
- **Crash hâlâ oluyorsa** bu senaryo değildir. **15 sn bekleyince crash yoksa** crash büyük ihtimalle bu ticker + GetPlayerController/FindAllOf/Pawn anı.

---

## 2. Ticker loading sırasında – FindFirstOf / SetText

**Ne zaman:** Yine **3 saniye** sonra ticker; bu sefer `ExtraRingDisplayName` dolu (yani daha önce Ctrl+G ile 3. yüzük atanmış). `refreshLabelOnly()` çağrılıyor.

**Hangi kod:** `refreshLabelOnly()` (satır 276) → `FindFirstOf("Widget_Inventory_C")`, sonra `widget.ItemTypeLabel` ve `label:SetText(...)`.

**Neden patlar:** Loading sırasında envanter widget’ı yok veya henüz hazır değil; FindFirstOf veya SetText native’de crash verebilir.

**Teyit:**  
- **Hiç Ctrl+G yapma** (3. yüzük atama). Sadece modu aç, Play Game’e bas, 3 sn içinde loading’de kal.  
- **Crash oluyorsa** tetikleyen büyük ihtimalle Case 1 (GetPlayerController/FindAllOf).  
- **Crash sadece bir kez 3. yüzük atadıktan sonra** Play Game veya sahneler arası loading’de oluyorsa, bu senaryo (FindFirstOf/SetText) aday.

---

## 3. Ctrl+G game thread dışında

**Ne zaman:** **Ctrl+G’ye bastığın anda** keybind callback’i çalışıyor. UE4SS dokümanına göre keybind callback’i her zaman game thread’de olmayabilir.

**Hangi kod:** `init()` (satır 703) → `RegisterKeyBind(Key.G, ..., function() safe(assignThirdRing) end)`. `assignThirdRing` içinde `getCharacter()` → `GetPlayerController()` → FindAllOf ve tüm engine erişimi **game thread garantisi olmadan** çalışıyor.

**Neden patlar:** Engine API’leri (GetPlayerController, FindAllOf, inventory, widget) sadece game thread’den güvenli. Başka thread’den çağrılırsa native crash.

**Teyit:**  
- Keybind callback’ini game thread’e al:  
  `RegisterKeyBind(Key.G, { ModifierKey.CONTROL }, function() ExecuteInGameThread(function() safe(assignThirdRing) end) end)`.  
- Aynı senaryoda (örn. loading sonrası hemen Ctrl+G) tekrarla.  
- **Crash kaybolursa** sebep bu.

---

## 4. RegisterHook – olmayan veya yanlış path

**Ne zaman:** **Ctrl+G’den hemen sonra** `registerEquipStatHooks()` çalışıyor (satır 634).

**Hangi kod:** `EQUIP_STAT_HOOK_PATHS` (satır 661–674) içindeki path’ler tek tek `RegisterHook(path, ...)` ile kaydediliyor. Örn. `/Script/GunfireRuntime.InventoryComponent:EquipItem`, `/Script/Remnant.RemnantPlayerInventoryComponent:EquipItem` vb. Bu path’ler Remnant build’inde birebir yoksa veya farklı isimdeyse native taraf patlayabilir.

**Neden patlar:** RegisterHook veya ilk ilgili fonksiyon çağrıldığında oyun bu UFunction’ı bulamıyor / yanlış obje; native crash.

**Teyit:**  
- `main.lua` içinde `ENABLE_EQUIP_POST_HOOK = false` yap. Sadece Ctrl+G atama ve stat uygulama kalsın, hook kaydı hiç çalışmasın.  
- **Crash kaybolursa** sorun hook path’lerinde.

---

## 5. tryApplyThirdRingStats – ApplyStats / AddModifier

**Ne zaman:** **Ctrl+G’ye bastığında** `assignThirdRing` içinde `pcall(tryApplyThirdRingStats)` (satır 632) çalışıyor.

**Hangi kod:** `tryApplyThirdRingStats()` (satır 288) → `statsComp:ApplyStats(bp, 0)`, `AddModifier(invItem)`, `ModifyStat(bp)` vb. Remnant’ın StatsComponent’i farklı imza veya state bekliyorsa (örn. henüz tam init olmamış, veya parametre tipi farklı) native crash.

**Neden patlar:** C++ tarafında ApplyStats/AddModifier/ModifyStat beklenmeyen obje veya state görünce crash.

**Teyit:**  
- `ENABLE_STAT_APPLY = false` yap. Sadece 3. yüzük atama ve label kalsın, stat uygulama hiç çalışmasın.  
- **Crash kaybolursa** sorun stat apply (ApplyStats/AddModifier/ModifyStat) tarafında.

---

## Özet tablo

| # | Tam ne zaman | Hangi kod / dosya | Teyit |
|---|----------------|--------------------|--------|
| 1 | Mod load + 3 sn, loading ekranındayken | scheduleLabelRefresh → GetPlayerController → FindAllOf / Pawn (UEHelpers) | İlk ticker’ı 15 sn geciktir; hemen Play Game. 15 sn sonra crash yoksa bu. |
| 2 | 3. yüzük atanmışken, 3 sn ticker loading’de | refreshLabelOnly → FindFirstOf("Widget_Inventory_C"), SetText | Hiç Ctrl+G yapma; crash varsa 1. Senaryo. Sadece atama sonrası loading’de crash ise bu. |
| 3 | Ctrl+G’ye basınca | assignThirdRing (GetPlayerController vb.) game thread dışında | assignThirdRing’i ExecuteInGameThread içinde çalıştır; crash giderse bu. |
| 4 | Ctrl+G sonrası hook kaydı | registerEquipStatHooks → RegisterHook(path) | ENABLE_EQUIP_POST_HOOK = false; crash giderse hook path’leri. |
| 5 | Ctrl+G’de stat uygulama | tryApplyThirdRingStats → ApplyStats / AddModifier | ENABLE_STAT_APPLY = false; crash giderse stat apply. |

Bu adımlarla hangi senaryonun sende gerçekten patlattığını netleştirebilirsin.
