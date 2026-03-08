## Remnant – Survival Mod (Görünmez 3. Yüzük) Planı

Bu dosyayı adım adım takip edeceğiz. Her adımı bitirdiğinde bir sonraki adıma geç.

---

## 1. UE4SS Kurulumu

1. Son sürümü indir:
   - Tarayıcıdan `https://github.com/UE4SS-RE/RE-UE4SS/releases` adresine git.
   - Listede sadece `dev` yazan zip dosyası varsa onu indir (örnek: `UE4SS_vX.Y.Z-dev.zip`).
2. Zip dosyasını aç.
3. İçindekileri oyunun `Binaries\Win64` klasörüne kopyala:
   - Senin için tahmini yol:
   - `c:\Users\alper\Desktop\remnant kopya\Remnant\Remnant\Binaries\Win64\`
   - Bu klasörde `Remnant-Win64-Shipping.exe` benzeri ana exe dosyası olmalı.
4. Kopyalama sonrası, `Win64` klasöründe hem oyunun exe’si hem de UE4SS dosyaları bulunmalı.

---

## 2. UE4SS’in Çalıştığını Doğrulama

1. `Remnant-Win64-Shipping.exe` dosyasını doğrudan `Win64` klasöründen çalıştır.
2. Oyun açılırken:
   - Ayrı bir konsol penceresi açılmalı veya
   - Ekranın bir köşesinde UE4SS ile ilgili yazılar görünmeli.
3. Eğer hiçbir şey görünmüyorsa:
   - UE4SS yanlış klasöre kopyalanmış olabilir.
   - Anti-cheat veya antivirus blokluyor olabilir (Remnant’ta genelde sorun olmaz).

Bu adımın sonunda:

- Oyun UE4SS ile sorunsuz açılıyor olmalı.

---

## 3. SDK Üretimi

Bu adımda oyunun class ve fonksiyon isimlerini çıkaracağız.

1. UE4SS dokümantasyonundaki SDK üretme bölümünü aç:
   - `https://trumank.github.io/RE-UE4SS/` adresinden ulaşabilirsin.
2. Oyun UE4SS ile çalışırken, SDK üretme komutunu uygula (dökümandaki tuş veya komutu kullan).
3. UE4SS, oyun klasörünün içinde bir `SDK` veya benzeri isimde klasör oluşturacak.
4. Bu klasörün içinde yüzlerce `.h` dosyası olacak; bunlar oyun class’larının tanımları.

Bu adımın sonunda:

- SDK klasörü oluşmuş olmalı.
- İçinde `Remnant` ile ilgili class tanımlarını görebilmelisin.

---

## 4. İlgili Class/Fonksiyonları Bulma

SDK içindeki `.h` dosyalarında şu anahtar kelimeleri ara:

- `Ring`
- `Equipment`
- `Inventory`
- `Survival`
- `Shop`, `Vendor`, `Buy`, `Purchase`

Özellikle şunları bulmaya çalış:

- Oyuncu karakter class’ı (örnek isimler):
  - `ARemnantPlayerCharacter`
  - `APlayerBase`
- Ekipman veya envanter class’ı:
  - `UEquipmentComponent`
  - `UInventoryComponent`
- Survival game mode veya world class’ı:
  - `ASurvivalGameMode`
  - `AGameMode_Survival`
- Pazar/vendor alışveriş fonksiyonu:
  - `BuyItem`
  - `PurchaseItem`
  - `OnItemBought`

Bu adımın sonunda:

- En azından:
  - Oyuncu class’ının adı,
  - Survival game mode class’ının adı,
  - Ring veya equipment ile ilgili bir class adı,
  - Vendor alışveriş fonksiyonunun imzası
  tespit edilmiş olmalı.

Bulduğun ilgili `.h` dosyalarından kısa parçaları daha sonra bu sohbete yapıştıracaksın.

---

## 5. Mod Mantığı (Görünmez 3. Yüzük)

Hedef:

- Sadece Survival modda,
- Pazardan alınan belirli bir yüzük (veya binder mekaniği üzerinden seçilen yüzük),
- Oyuncunun statlarına ekstra bir modifier seti olarak eklenecek.

Genel değişkenler:

- `ExtraRingId`: O anki run içinde görünmez üçüncü yüzüğün kimliği.

Olay akışı:

1. Oyun survival modda mı:
   - Survival game mode class’ı üzerinden kontrol edilecek.
2. Pazardan item alındığında:
   - Alınan item bir ring ise veya özel bir binder item’i ise:
     - `ExtraRingId` güncellenecek veya temizlenecek.
3. Oyuncunun statları güncellenirken:
   - Normal 2 yüzük için hesaplanan buff’lara ek olarak,
   - `ExtraRingId` için de aynı ring’in buff’ları manuel uygulanacak.

Bu adımda henüz kod yazmıyoruz, sadece davranış net.

---

## 6. Lua Mod İskeleti Oluşturma

Bu adımda:

- UE4SS mod klasörüne yeni bir mod klasörü oluşturulacak (örnek: `Mods/SurvivalExtraRing/`).
- İçine bir Lua dosyası eklenecek (örnek: `main.lua`).
- Lua dosyasında:
  - Survival mod kontrol fonksiyonu,
  - Vendor alışveriş hook’u,
  - Extra ring stat uygulama fonksiyonu,
  - Oyuncu ringleri değiştiğinde ekstra buff’ı tekrar uygulayan fonksiyon
  yer alacak.

Önemli:

- Kullanılacak class ve fonksiyon isimleri, 4. adımda SDK’dan tespit ettiğin gerçek isimler olacak.
- Kod içinde yorum satırı olmayacak.

---

## 7. Test ve Ayar Çekme

1. Mod etkin halde oyuna gir:
   - Survival modda yeni bir run başlat.
2. Pazardan ring veya binder item’i al:
   - `ExtraRingId` doğru güncelleniyor mu, statlar beklediğin gibi artıyor mu kontrol et.
3. Farklı ring kombinasyonları dene:
   - Çok güçlü veya bozuk kombinasyonlar varsa gerekirse bazı ring’leri ekstra ring olmaktan hariç tut.

Bu adımda sık sık oyunu kapatıp açman ve Lua kodunu küçük küçük düzeltmen gerekecek.

---

## 8. Bir Sonraki Adım (Şimdi)

Şu anda yapman gereken:

1. Bu dosyayı oku.
2. 1. ve 2. adımı uygula:
   - UE4SS’i indirip `Binaries\Win64` klasörüne kur.
   - Oyunu çalıştırıp UE4SS’in gerçekten çalıştığını doğrula.
3. Bunlar tamam olduğunda:
   - Bana:
     - Oyunun exe’sinin tam yolunu,
     - UE4SS’in açılışta gösterdiği kısa metni (konsolda gördüğün önemli satırlar)
     yaz.

Sonra buradan birlikte 3. ve 4. adımlara, ardından da Lua iskeletine geçeceğiz.

