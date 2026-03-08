# Survival 3. Yüzük – İnce Eleyip Sık Dokuma (Detay + Açık Noktalar)

Bu dosya teknik planı tamamlar: edge case’ler, oyun özellikleri, netleştirilmesi gereken kararlar ve implementasyonda dikkat edilecek noktalar.

---

## A. Oyun özellikleri ve mod etkisi

### A.1 Survival run yapısı
- **Run bittiğinde / ölüm:** Survival’da run bittiğinde (ölüm vb.) ilerleme sıfırlanır. Mod state’i (3. yüzük ataması) **sadece o run’ın canlı oturumunda** tutuluyor; oyunun save sistemine yazmıyoruz.
- **Survival’da save/load yok:** Run içi kayıt yok; persistence (dosyaya yazma) gerekmez. Atama sadece bellekten; run bitince zaten sıfırlanır.

### A.2 Çok oyunculu (co-op)
- Survival co-op açılabiliyor. Her oyuncunun kendi envanteri var.
- **Mod nerede çalışır:** UE4SS modu oyunu çalıştıran makinede (client veya host). Yani mod **senin** client’ında yüklüyse **senin** 3. slotun çalışır; diğer oyuncunun modu yoksa onun 3. slotu yok.
- **Senkron:** 3. yüzük sadece lokal efekt (stat/buff); oyun sunucusu “3. slot” bilmiyor. Diğer oyuncular senin 3. yüzüğünü görmez (sadece 2 slot görünür). Bu kabul edilebilir.
- **Host vs client:** Host’ta mod varsa host’un 3. slotu çalışır; client’ta mod varsa client’ın. Çakışma yok.

### A.3 Amulet vs Ring – 3. slot sadece yüzük
- Oyunda **trinket** listesi var; bu listeden **1 kolye (amulet) + 2 yüzük (ring)** takılabiliyor. Mod **sadece +1 yüzük** ekliyor → toplam **1 amulet + 3 ring**.
- **3. slot sadece yüzük:** Sayım “en az 3 farklı **yüzük**” (ring); kolye sayılmaz. 3. slota atanacak item da **sadece ring** olabilir. Oyun verisinde ring vs amulet ayrımı (isim, tag veya alt tip) ile filtrelenecek.

### A.4 Hardcore / Campaign / Adventure
- Plan: Sadece **EQuestMode::Survival**. Campaign ve Adventure’da mod 3. slotu açmaz. Hardcore (ERemnantCharacterType::Hardcore) ayrı; Survival modu değil. Sadece **QuestGameMode == Survival** kontrolü yeterli.
- **Quest bilgisi:** `GetActiveRootQuest()` (Remnant.hpp’ta var) ile aktif root quest alınır; `ARemnantQuest::QuestGameMode` (offset 0x042D) ile Survival kontrolü yapılır.

**GetActiveRootQuest yolu ne demek (basit):**  
Oyunda “şu an Survival mıyız?” bilgisi **aktif quest**’te tutuluyor. Kod tarafında şu zincirle okuyoruz: (1) **World** = o an yüklü harita/level, (2) World’den **GameState** = oyunun genel durumu (skor, quest listesi vb.), (3) GameState’te **RemnantQuestManager** = quest’leri yöneten component (bellekte 0x04A0 offset’inde), (4) bu component’in **GetActiveRootQuest()** fonksiyonu = “şu an oynanan run’ın quest’i”, (5) dönen **ARemnantQuest** nesnesinin **QuestGameMode** alanı = Campaign / Adventure / **Survival**. Yani: World → GameState → RemnantQuestManager → GetActiveRootQuest() → QuestGameMode. Bu yol “Survival’da mıyız?” sorusunun cevabını verir.

---

## B. “En az 3 farklı yüzük” sayımı (sadece ring)

### B.1 Farklı = unique ItemBP, sadece yüzükler
- **Sadece ring** sayılır; amulet (kolye) sayılmaz. Envanterde 2 ring + 1 amulet varsa = **2 yüzük** → 3. slot açılmaz. En az **3 farklı ring** (unique ItemBP, ring tipinde) gerekir.
- **Teknik:** GetItems → **ring** olanları filtrele (oyunda ring/amulet ayrımı isim, tag veya ItemType/alt kategori ile yapılacak) → unique ItemBP say. >= 3 ise 3. slot kullanılabilir.

### B.2 Slot 1 ve 2’deki takılı trinketler
- `FindItemByEquipSlotNameID(FName("Trinket1"))` ve `FName("Trinket2")` ile slot 1 ve 2’deki item alınır (FInventoryItem). Binder’da “slot 1 ve 2’de takılı olmayan” liste için bu iki item’ın ItemID/ItemBP’si hariç tutulur.
- **Slot isimleri:** Object dump’ta Trinket1Slot, Trinket2Slot geçiyor; slot NameID’nin "Trinket1" / "Trinket2" olduğu varsayılır (oyunda test veya dump ile doğrulanmalı).

---

## C. 3. yüzük ataması (binder) – açık noktalar

### C.1 “3. slota ata” nasıl yapılacak?
- **Seçenekler:**  
  - **1)** Envanter Trinket sekmesinde bir item seçiliyken **belirli bir tuş** (örn. T veya G) “Bunu 3. slota ata” yapar.  
  - **2)** Envanterde sağ tık / alt menüde “3. slota ata” seçeneği (UI hook gerekir).  
  - **3)** Trinket listesinde item’ın yanında küçük bir “3” butonu (widget inject zor).  
- **Pratik:** Tuş (RegisterKeyBind) ile “şu an seçili trinket’ı 3. slota ata” en kolay. Envanterde “selected item” bilgisi Widget_Inventory’de SelectedItemID veya InventoryList’ten alınabilir.

### C.2 “3. slotu boşalt”
- Oyuncu 3. yüzüğü çıkarmak isteyebilir. Bir tuş veya aynı yüzüğe tekrar “3. slota ata” deyince toggle mı, yoksa ayrı “Clear 3rd slot” mı? Netleştirilmeli.

### C.3 Atanmış yüzük slot 1 veya 2’ye takılırsa
- 3. slota “Ring A” atanmışken oyuncu Ring A’yı slot 1 veya 2’ye takarsa: **3. atamayı otomatik temizlemek** mantıklı (aynı yüzük iki yerde olmasın). Ya da slot 1/2’ye takarken “bu 3. slotta atılı, önce 3. slotu boşalt” uyarısı. En basiti: 3. slot efektini uygularken kontrol et; eğer ExtraRingItemID şu an slot 1 veya 2’de takılıysa 3. slotu boş say (veya atamayı temizle).

### C.4 Atanmış yüzük satıldı / düşürüldü / kullanıldı
- Oyunda **yüzük/zırh satılmıyor**; satılanlar genelde consumable (pot, adrenaline vb.). Trinket envanterden ancak **drop** veya başka bir şekilde (quest, ölüm vb.) çıkabilir.
- 3. slota atanmış item envanterden çıkarsa (drop vb.) atama **geçersiz** olmalı. Her efekt uygulaması veya envanter açılışında: `FindItemByID(ExtraRingItemID)` hâlâ var mı diye bak; yoksa ExtraRingItemID = 0 (veya nil).

---

## D. ItemID + level (neden ItemID saklanmalı?)

- **ItemBP** = item **tipi** (örn. “Ring of the Unclean”). Aynı tipten envanterde birden fazla **instance** olabilir.
- **Yüzüklerin level’ı yok**; Survival’da silahlar da dahil item level’ı olmadığı için stat uygularken **level = 0** (veya sabit 1) kullanılır. ItemID yine **“hâlâ envanterde mi?”** kontrolü için değerlidir.
- **Ne işe yarıyor (ItemID):** (1) 3. slota atadığın **somut envanter kalemi** – hâlâ var mı? FindItemByID ile kontrol. (2) İleride başka item türlerinde level gerekirse aynı mantık kullanılır; yüzüklerde level olmadığı için ApplyStats(..., 0) yeterli.
- **Özet:** 3. slot için ItemID = “hangi kalem atandı” ve “hâlâ envanterde mi?”; **level** yüzüklerde kullanılmıyor.

---

## E. UI (envanter label) – detay

### E.1 Widget’a ne zaman erişilir
- Envanter ekranı açıldığında Widget_Inventory_C oluşturulur (lazy olabilir). **Hook:** Envanter/dialog açılışında veya Trinket tab’a geçildiğinde bir kez (veya kısa aralıklarla) `FindFirstOf("Widget_Inventory_C")` ile widget bulunur; ItemTypeLabel set edilir.
- Oyun kendi “Trinketler” yazısını başka bir event’te tekrar yazıyorsa (refresh), bizim SetText’imiz ezilebilir. **Çözüm:** Trinket tab görünürken periyodik (örn. her 0.5 sn) veya OnInventoryChanged / OnTabFocus gibi bir event’te label’ı tekrar set etmek.

### E.2 İsim nereden gelecek
- 3. yüzük için gösterilecek isim: item’ın **display name** (FText). FInspectInfo::Label veya item CDO’dan label alınır. ItemID varsa envanter item’ının InspectInfo’u (veya GetInspectInfo benzeri) kullanılabilir.

### E.3 Dil
- Label metni: **“3rd Ring:”** (İngilizce). Planla uyumlu.

---

## F. Efekt uygulama – ek detaylar

### F.1 Stat ne zaman uygulanacak
- **Seçenekler:** (1) Her frame/tick – gereksiz yük. (2) Inventory changed / Equip event’inde. (3) StatsComp’ta Invalidate/ComputeStats tetiklendiğinde (hook varsa). (4) Periyodik (örn. her 1 sn).
- **Öneri:** Envanter veya equip değişince + periyodik 1 sn (güvenlik ağı). Böylece oyun kendi stat’ı invalidate etse bile bir saniye içinde 3. yüzük stat’ı tekrar uygulanır.

### F.2 ApplyStats çift uygulama
- 3. yüzük zaten slot 1 veya 2’de takılı olan bir item **olmamalı** (binder kuralı). Ama yanlışlıkla aynı item hem takılı hem 3. slotta atanmışsa **çift stat** uygulanır. Bu yüzden “3. slot = slot 1 ve 2’de olmayan” kontrolü şart.

### F.3 Bilinmeyen trigger tipleri
- Trinket için SDK’da **4** tetikleyici tip var: TriggerOnEquip, TriggerOnMeleeHit, TriggerOnEvent, TriggerOnUseDragonHeart. **Perfect dodge → patlama**, **can %50 koruma** gibi efektler büyük ihtimalle TriggerOnEvent (event adı: perfect dodge, health threshold vb.) veya TriggerOnEquip altında. Modda bu event’ler hook’lanıp 3. yüzük için aynı Action tetiklenecek. Başka bilinmeyen tip çıkarsa sadece stat uygulanır.

---

## G. Performans ve güvenlik

### G.1 Tick / timer
- Çok sık FindFirstOf veya GetItems çağırmak maliyetli olabilir. Envanter açık değilken label güncellemesi yapılmaz; açıkken de sadece Trinket tab’da ve en fazla 1–2 sn’de bir güncelleme yeterli.

### G.2 Nil / invalid kontrolü
- Her adımda: PlayerController, Character, Inventory, StatsComp, Widget, ItemBP/ItemID için nil ve IsValid kontrolü. Crash’i önlemek için kritik.

---

## H. Konuşulması / karar verilmesi gerekenler (özet)

| # | Konu | Seçenekler / not |
|---|------|-------------------|
| 1 | **Binder UI** | “3. slota ata” tek tuşla mı (seçili item), yoksa menü/buton mu? “3. slotu boşalt” ayrı mı? |
| 2 | **Persistence** | Survival’da save/load yok; persistence gerekmez. |
| 3 | **Slot NameID** | Trinket1/Trinket2 FName’leri oyunda tam olarak ne? (Test veya dump ile doğrulanacak.) |
| 4 | **GetActiveRootQuest erişimi** | World → GameState (TPSGameState veya Remnant variant) → `RemnantQuestManager` (offset 0x04A0) → `GetActiveRootQuest()` → `ARemnantQuest::QuestGameMode`. Lua’da World/GameState’ten bu zincir kurulacak. |
| 5 | **Item display name** | FInspectInfo veya item’dan FText label almak için tam API (Lua’da nasıl çağrılır). |
| 6 | **ApplyStats imzası** | UStatsComponent::ApplyStats(DataTableRowHandle, Level) Lua’dan ProcessEvent ile mi çağrılacak; row handle item’dan nasıl alınacak? |

---

## I. Implementasyon sırası (detaylı)

1. **Temel mod iskeleti** – mod klasörü, main.lua, mods.txt.
2. **Survival kontrolü** – GetActiveRootQuest (veya eşdeğeri) + QuestGameMode == Survival; sadece Survival’da devam.
3. **En az 3 farklı trinket** – GetItems + ItemType Trinket filtresi + unique ItemBP sayısı >= 3.
4. **3. slot ataması** – ExtraRingItemID (ItemID) tutma; binder tuşu + “slot 1/2’de olmayan” listesi; satış/drop/equip ile temizleme.
5. **Envanter label** – Widget_Inventory_C + ItemTypeLabel; Trinket tab’da “3. Yüzük: [İsim]”; güncelleme zamanlaması.
6. **Stat uygulama** – StatsComp bulma; 3. yüzük item’ının level + stat row’u; ApplyStats veya stat modifier; tetikleme zamanlaması.
7. **TriggerOnEquip** – 3. yüzük atandığında ilgili Action/Buff’ı spawn + start.
8. **Diğer trigger tipleri** – MeleeHit, Event, DragonHeart (sonraki iterasyon).

Bu liste, “ince eleyip sık dokuma” ve “başka konuşmamız gereken ne var” sorusunun cevabıdır; teknik planla birlikte kullanılmalı.
