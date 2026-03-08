# Remnant – Survival Third Ring Mod

UE4SS (Lua) modu: **Survival** modunda 3. yüzük slotu. Oyunda 1 amulet + 2 ring var; bu mod ile ekstra 1 yüzük (3. ring) atanabiliyor. Stat'lar ApplyStats/AddModifier/ModifyStat ile uygulanmaya çalışılıyor; envanterde "3rd: [yüzük adı]" etiketi gösteriliyor.

---

## Gereksinim

- **Remnant** (Steam)
- **UE4SS 3.x**
- **UEHelpers** – `Mods/shared/UEHelpers` (UE4SS ile gelen veya paylaşılan mod klasörü)

---

## Kurulum

1. [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) kurulu Remnant kurulumunda `Mods` klasörüne `SurvivalThirdRing` klasörünü kopyala.
2. Klasör yapısı: `Mods/SurvivalThirdRing/Scripts/main.lua` (+ isteğe bağlı `Docs/`).
3. `Mods/mods.txt` içinde `SurvivalThirdRing : 1` olduğundan emin ol.

**Steam kurulumunda mod yolu örneği:**  
`C:\Program Files (x86)\Steam\steamapps\common\Remnant\Remnant\Binaries\Win64\Mods\SurvivalThirdRing\`

---

## Kullanım

- **Ctrl+G** – Envanterde **seçili** yüzüğü 3. slota ata. Envanteri aç, Trinket listesinden bir yüzüğe tıkla (seçili olsun), sonra Ctrl+G bas.
- **Ctrl+Y** – 3. slotu temizle.
- **F6** – 3. yüzük durumunu konsola yazar.

Envanterde Trinket sekmesinde "3rd: [yüzük adı]" etiketi görünmesi hedeflenir (oyun bazen üzerine yazıyorsa ticker 3 sn'de bir tekrar yazar).

---

## Davranış / mantık

- **Init:** Mod yüklendikten **15 saniye sonra** keybind'ler kaydedilir (erken engine erişimi crash'i önlemek için). Konsolda "SurvivalThirdRing: keybinds registered" görürsün.
- **UEHelpers:** İlk kullanımda lazy yüklenir (require script açılışında değil, ilk Ctrl+G'de). Böylece oyun açılırken engine'e dokunulmaz.
- **Ticker:** Sadece **ilk Ctrl+G'den sonra** başlar; her 3 saniyede "3rd: X" label'ını yeniler. Init'te ticker yok, loading sırasında crash riski azalır.
- **Keybind'ler:** Tüm tuş callback'leri `ExecuteInGameThread` içinde çalışır; engine API'leri game thread'den çağrılır.
- **3. yüzük slot 1/2'ye taşınırsa:** Mod otomatik temizler (ExtraRingItemID/BP/DisplayName sıfırlanır, label "Trinket" yapılır).

---

## Log / hata ayıklama

- **Log dosyası (Steam):**  
  `C:\Program Files (x86)\Steam\steamapps\common\Remnant\Remnant\Binaries\Win64\UE4SS.log`  
  UE4SS GUI'de Console sekmesinden de aynı çıktıyı görebilirsin.

- **Ctrl+G sonrası arayacağın satırlar:**
  - `[SurvivalThirdRing] --- assignThirdRing (Ctrl+G) ---`
  - `[SurvivalThirdRing] Ring count: ...` / `Selected itemID: ...`
  - `[SurvivalThirdRing] 3rd ring assigned: ...`
  - **Label için:**  
    - `[SurvivalThirdRing] 3rd label: yazıldı -> 3rd: ...` → yazı başarılı  
    - `[SurvivalThirdRing] 3rd label: Widget_Inventory_C not found ...` → envanter kapalı veya widget ismi farklı  
    - `[SurvivalThirdRing] 3rd label: ItemTypeLabel yok veya geçersiz` → widget var ama label alanı yok/farklı

---

## main.lua içindeki ayarlar (üst kısım)

| Değişken | Varsayılan | Açıklama |
|----------|------------|----------|
| `LOG_VERBOSE` | `false` | Detaylı adım logları (logStep) |
| `ENABLE_STAT_APPLY` | `true` | 3. yüzük stat'larını uygula (ApplyStats/AddModifier/ModifyStat) |
| `ENABLE_EQUIP_POST_HOOK` | `true` | Equip/stat hook'larını kaydet; equip sonrası stat'ları tekrar uygular |
| `LOG_EQUIP_HOOK` | `true` | Hook tetiklenince "[HOOK] path" logla |
| `LOG_DEBUG_STEPS` | `false` | step 0/1/2... debug logları |

Crash veya garip davranışta: önce `ENABLE_EQUIP_POST_HOOK = false`, gerekirse `ENABLE_STAT_APPLY = false` dene (Docs/CRASH_SENARYOLARI.md'deki teyit adımlarına göre).

---

## Neden crash olur (kısa)

- Engine'e **oyun/dünya hazır olmadan** veya **game thread dışında** erişmek (GetPlayerController, FindAllOf, Pawn, widget, stats).
- Bu modda yapılanlar: init 15 sn gecikmeli, UEHelpers lazy, keybind'ler ExecuteInGameThread'de, ticker sadece Ctrl+G sonrası, tüm UE objelerinde IsValid() ve pcall kullanımı. Detaylı senaryolar ve teyit: **Docs/CRASH_SENARYOLARI.md**.

---

## UI / label notu

Label yazılan yer: **Widget_Inventory_C** → **ItemTypeLabel**. Remnant sürümünde widget veya property ismi farklıysa (veya oyun sürekli üzerine yazıyorsa) "3rd: X" görünmeyebilir; log'daki "3rd label: ..." satırına bakarak widget/label bulunamadı mı anlaşılır.

---

## Klasör yapısı (repo)

```
SurvivalThirdRing/
  README.md
  Scripts/
    main.lua
  Docs/
    CRASH_SENARYOLARI.md
    NOTLAR_OBJE_ISIMLERI_VE_ADIMLAR.md
    STAT_APPLY_TRIED.md
    survival_3rd_ring_teknik_plan.md
    survival_3rd_ring_detay_ve_acik_noktalar.md
    remnant_survival_extra_ring_plan.md
```

Teknik plan ve crash teyit adımları için **Docs/** klasörüne bak.

---

## Workspace vs Steam

Script'i workspace'te (örn. masaüstü kopyası) düzenleyip oyunu Steam'den açıyorsan, değişikliklerin yansıması için `Scripts/` (ve gerekirse tüm mod) klasörünü Steam'deki `Mods/SurvivalThirdRing/` altına kopyalaman gerekir. Repo Steam tarafındaki bu klasör üzerinden de tutulabilir.
