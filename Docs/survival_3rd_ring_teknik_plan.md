# Survival 3. Yüzük – Teknik Plan (Oyuna Yedirme)

## 1. Oyunun slot yapısı

- **Oyunda trinket slotları:** 2 slot. Bu 2 slotta oyuncu **1 kolye (amulet) + 2 yüzük (ring)** takabiliyor; yani liste trinket listesi ama pratikte 1 amulet + 2 ring kullanılıyor.
- **İstenen:** Aynı listeden **1 yüzük daha** takabilmek → toplam **1 amulet + 3 ring**. Mod sadece **ekstra 1 yüzük** (3. ring) ekliyor; kolye sayısı değişmiyor.
- **UI/veri:** `Trinket1Slot`, `Trinket2Slot`; `EquipmentSlots` içinde 2 trinket slotu var. 3. slot **yok**; mod “görünmez 3. yüzük slotu” tutacak ve sadece **yüzük** (ring) atanacak.
- **Sonuç:** 3. slot = **sadece yüzük**. Sayım ve atama “en az 3 farklı **yüzük**” ve “3. slota sadece **yüzük** atanır” olacak; amulet bu slotta kullanılmaz.

---

## 2. 3. slot koşulu: En az 3 farklı yüzük (sadece ring; aynı yüzükten 2 takılamaz)

- **Kural:** Oyunda 1 amulet + 2 ring takılıyor; mod +1 **yüzük** ekliyor. Aynı yüzükten 2 tane takılamaz; 3. slot için **en az 3 farklı yüzük** (ring) gerekir. Sayım ve atama **sadece yüzükler** (ring) üzerinden; kolye (amulet) 3. slota atanamaz ve “en az 3 yüzük” sayımına dahil değil.
- **Hedef:** 3. slot ancak **envanterde en az 3 farklı yüzük** (ring) varken kullanılabilsin. 3. yüzük ataması da sadece **ring** tipindeki item’lardan yapılır.
- **Akış:**
  1. **3. slot açık mı:** Envanterde (takılı + envanter) **en az 3 farklı ring** var mı say (amulet sayılmaz). Evetse 3. slot seçilebilir.
  2. **3. yüzük ataması (binder):** Oyuncu envanterden, **yüzük** (ring) olan ve **slot 1–2’de takılı olmayan** bir item seçip “3. slota ata” der; modda `ExtraRingItemID` / `ExtraRingItemBP` set edilir.
- **Teknik:** Oyun verisinde ring vs amulet ayrımı (ItemType/alt kategori veya isim/tag) tespit edilecek; sadece ring’ler sayılacak ve sadece ring atanabilecek.

Özet: **1 amulet + 2 ring (oyun) → mod ile 1 amulet + 3 ring. 3. slot sadece yüzük; en az 3 farklı yüzük = 3. slot kullanılabilir.**

---

## 3. 3. yüzüğün isminin envanterde görünmesi (konsol yok)

- **Hedef:** Konsolla uğraşmadan, **envanter ekranında** bir TextBlock/label’da “3. Yüzük: [İsim]” görünsün.
- **Yöntem (Lua + SetText):**
  - Envanter widget’ı: `Widget_Inventory_C` (Trinket sekmesi açıkken bu widget görünür). İçinde kullanılabilir TextBlock’lar:
    - `ItemTypeLabel` (0x0388) – sekme başlığı gibi (örn. “Trinketler”). Trinket sekmesindeyken buna ek olarak “ | 3. Yüzük: [İsim]” eklenebilir veya tamamen “3. Yüzük: [İsim]” yapılabilir.
    - `Widget_EquipmentSlot_Small_C::Label` (0x03C8) – slot başına label (Trinket1Slot, Trinket2Slot’ta “Trinket 1”, “Trinket 2” yazar). 3. slot için yeni bir slot widget’ı eklemek yerine, **mevcut bir label’ı** (örn. ItemTypeLabel veya envanterdeki başka bir TextBlock) kullanmak daha kolay.
  - **Pratik seçenek:** Trinket sekmesi açıkken `Widget_Inventory_C` bulunur (`FindFirstOf("Widget_Inventory_C")` veya açık dialog’dan), `ItemTypeLabel` alınır; 3. slot atanmışsa `ItemTypeLabel:SetText(FText("Trinketler  |  3rd Ring: " .. ring_display_name))`, atanmamışsa sadece “Trinketler”. Label metni İngilizce: **“3rd Ring:”**. Envanter her açıldığında / Trinket tab’a geçildiğinde bu güncellenir.
- **UE4SS Lua:** `FText("metin")` ile FText oluşturulur; `UTextBlock::SetText(FText)` ile yazı set edilir. Widget’a `FindFirstOf` / `StaticFindObject` ile erişilir (envanter açıkken instance var olmalı).

Konsol kullanılmayacak; sadece envanterdeki label güncellenecek.

---

## 4. 3. yüzüğün efektlerinin gerçekten çalışması (ek kod şart)

Oyun sadece **2 trinket slot**unu okuyup onların ekipmanını uyguluyor. 3. yüzüğü hiçbir yerde “takılı” göstermiyoruz; ama **efektini** (stat / buff / trigger) oyuncuya uygulamamız lazım. Bu yüzden **mutlaka ek kod (mod tarafında) gerekir.**

### 4.1 Stat etkisi (pasif sayısal bonuslar)

- Karakter: `ARemnantCharacter` → `StatsComp` (`UStatsComponent`, offset 0x0760 `ACharacterGunfire`’dan).
- Yüzükler **level’a sahip değil**; **Survival’da** silahlar da dahil genelde item level’ı yok (+1 / +10 upgrade yok). Stat uygularken tek seviye (örn. level 0 veya 1) kullanılır.
- Yüzüklerin bir kısmı **sadece stat** veriyor (örn. menzil artışı / range). Oyun takıldığında `UStatsComponent::ApplyStats(DataTableRowHandle, Level)` benzeri bir yol kullanıyor; mod da 3. yüzük için aynı stat’ı uygulayacak.
- **Modun yapacakları:** Survival + 3. slot açık + 3. yüzük atanmış (ItemBP / ItemID). Oyuncunun `StatsComp`’ına 3. yüzük item’ının stat bilgisini (DataTable row veya FInspectInfo.Stats) uygula; **level = 0** (yüzüklerin level’ı yok). ItemID yine “envanterde hâlâ var mı?” kontrolü için kullanılır.

Evet, **menzil artıran yüzük** gibi pasif stat veren tüm yüzükler bu şekilde ele alınacak.

### 4.2 Trigger / aksiyon etkileri – tüm tipler (perfect dodge, can koruma, vb.)

Yüzükler sadece stat değil; **tetikleyici** (trigger) efektler de var. Örnekler: **perfect dodge yapınca küçük patlama**, **canın %50’nin altına inmesini engelleyen** yüzük, menzil artışı (stat). Bunların hepsi modda ele alınacak.

| Tip (base class) | Ne zaman tetiklenir | Örnek / açıklama | Modda yapılacak |
|------------------|---------------------|-------------------|------------------|
| **Item_Trinket_TriggerOnEquip** | Takılınca | Sürekli buff / “takılıyken geçerli” efektler | 3. yüzük “takılı” sayıldığında ilgili Action/Buff spawn + uygula. |
| **Item_Trinket_TriggerOnMeleeHit** | Melee vuruşunda | Yakın dövüş tetiklemeli | Melee hit event’ini hook’la; 3. yüzük bu türdense Action tetikle. |
| **Item_Trinket_TriggerOnEvent** | Belirli oyun event’i | Perfect dodge, can eşiği vb. (event adı oyunda tespit edilecek) | Event’i hook’la; 3. yüzük bu türdense aynı Action’ı tetikle. |
| **Item_Trinket_TriggerOnUseDragonHeart** | Dragon Heart kullanınca | Volatile Gem vb. | Dragon Heart kullanımını hook’la; 3. yüzük bu türdense Action başlat. |
| **Item_Trinket_Base** (sadece stat) | – | Menzil artışı gibi pasif | Sadece ApplyStats (level 0). |

- **Perfect dodge → patlama** ve **can %50 koruma** gibi efektler büyük ihtimalle **TriggerOnEvent** veya **TriggerOnEquip** altında; oyun event’leri (perfect dodge, health threshold) tespit edilip 3. yüzük için aynı Action tetiklenecek.
- Özet: **Silah menzili artıran, perfect dodge patlaması yapan, can koruma veren** tüm yüzük efektleri (stat + trigger) modda uygulanacak.

---

## 5. Kısa uygulama sırası

1. **Survival kontrolü:** `ARemnantQuest::QuestGameMode == EQuestMode::Survival` (veya mevcut root quest’ten).
2. **3. slot kullanılabilir mi:** Envanterde (takılı + envanter) **sadece yüzükler** (ring) sayılarak **en az 3 farklı ring** var mı kontrol et; evetse 3. slot seçilebilir. Amulet sayılmaz.
3. **3. yüzük ataması (binder):** Envanterden **sadece ring** olan ve slot 1–2’de takılı olmayan bir item seçilip “3. slota ata” ile `ExtraRingItemID` / `ExtraRingItemBP` set edilir.
4. **İsim – envanterde TextBlock:** Trinket sekmesi açıkken `Widget_Inventory_C` → `ItemTypeLabel` (veya uygun Label) bulunup `SetText(FText("Trinketler  |  3rd Ring: " .. ring_name))` ile güncellenir. Label metni: **“3rd Ring:”** (İngilizce). Konsol kullanılmaz.
5. **Efekt (stat):** Yüzüklerin level’ı yok; level 0 ile ApplyStats (veya eşdeğeri). Periyodik veya equip sonrası player `StatsComp` + 3. yüzük stat’ı.
6. **Efekt (trigger):** Tüm tipler (TriggerOnEquip, MeleeHit, Event, DragonHeart) için ilgili Action/Buff tetiklenir; **perfect dodge patlaması, can %50 koruma, menzil artışı** vb. tüm yüzük efektleri kapsanır.

Bu plan, oyundaki **1 amulet + 2 ring** yapısına **+1 ring** (sadece yüzük) ekler; sayım ve atama sadece yüzüklerle yapılır, yüzüklerde level yok, tüm ring efektleri (stat + trigger) uygulanır.
