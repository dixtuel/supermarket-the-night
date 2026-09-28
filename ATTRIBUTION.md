# Proje Varlık ve Lisans Kayıtları (Attribution)

Bu belge, *Supermarket: The Night* projesinde kullanılan tüm üçüncü taraf varlıkların ve açık kaynak kaynakların telif/lisans bilgilerini kayıt altına almaktadır.

> [!NOTE]
> Proje kodları ve oyun mantığı sıfırdan geliştirilmiştir; başka herhangi bir oyundan kod veya içerik birebir alınmamıştır.

---

## 1. Açık Kaynak Görsel & Arayüz Varlıkları (Kenney)

Aşağıdaki varlıklar, kamu malı (**CC0 1.0 Universal**) lisansı ile Kenney (Kenney Vleugels) tarafından sağlanmıştır:

### • Top-Down Shooter Pack
- **Oluşturucu:** Kenney ([kenney.nl](https://kenney.nl))
- **Kaynak:** https://kenney.nl/assets/top-down-shooter
- **Lisans:** [CC0 1.0 Universal](http://creativecommons.org/publicdomain/zero/1.0/)
- **Kullanılan Dosyalar:** `survivor.png`, `zombie.png`, `gun.png`, `tile_floor.png`

### • Crosshair Pack
- **Oluşturucu:** Kenney ([kenney.nl](https://kenney.nl))
- **Kaynak:** https://kenney.nl/assets/crosshair-pack
- **Lisans:** [CC0 1.0 Universal](http://creativecommons.org/publicdomain/zero/1.0/)
- **Kullanılan Dosyalar:** `crosshair.png` (Nişan imleci olarak kullanılmıştır)

### • UI & Font Pack
- **Oluşturucu:** Kenney ([kenney.nl](https://kenney.nl))
- **Kaynak:** https://kenney.nl/assets/ui-pack
- **Lisans:** [CC0 1.0 Universal](http://creativecommons.org/publicdomain/zero/1.0/)
- **Kullanılan Dosyalar:** `button.png`, `xp_orb.png`, `font_kenney_future.ttf`

---

## 2. Orijinal Proje Çizimleri & Varlık Üretimi

- **Oda ve Sahne Arka Planları:** OpenAI Image 2.5 kullanılarak proje temasına ve oda planlarına uygun biçimde orijinal olarak üretilmiştir (`assets/generated/rooms/`).
- **Mağaza ve Yetenek İkonları:** Projenin gece marketi temasına özel olarak üretilmiş 20 adet özgün ikon içermektedir (`assets/generated/shop_icons/`).
- **Yeni içerik paketi görselleri:** Barcode Reel ve Quiet-Shift Footwork ikonları; Receipt Moth, Pallet Stacker Boss, Scanline Runner, Coupon Tosser, Cooler Dripper, Pallet Jack Pusher ve Night Shift Supervisor statik sprite'ları; Engineering Caddy ve Reinforced Apron Plus ikonları OpenAI ImageGen ile özgün olarak üretilmiştir (`assets/generated/content_pack/`). Aisle Sentinel, Spill Tripmine, Thermal Price Gun, Tote-Stack Lobber ve Deposit-Ring Reel için özgün SVG ikonları proje içinde hazırlanmıştır. Bu görseller ayrı `ASSET_LICENSE.md` dosyasındaki CC0 1.0 varlık lisansına dahildir. Depot Emergency Radio mevcut enerji pickup görselini kullanır.
- **Yardımcı, taret, mayın ve depo kasası görsel düzeltmeleri (29 Eylül 2026):** `temporary_shift_helper_walk.png` yardımcı için dört yönlü özgün atlas olarak OpenAI ImageGen ile üretildi; hareket/yön takibi kodu proje içinde yazılmıştır. Aisle Sentinel ve Spill Tripmine SVG'leri ile `depot_floor_crate.svg` zemin teması ve 3/4 görünüm için proje içinde özgün çizilmiştir. Bunlar ayrı `ASSET_LICENSE.md` dosyasındaki CC0 1.0 varlık lisansına dahildir; GDScript MIT lisanslı kaynak kod olarak kalır.
- **DNZ ve Müdür karakter çizimleri (29 Eylül 2026):** `player_dnz.png`, `player_dnz_walk.png` ve `dnz_manager_walk.png` mevcut Night Clerk atlası referans alınarak OpenAI ImageGen ile özgün biçimde üretildi. `milk_hose.svg` proje içinde özgün çizildi. Dört yönlü atlaslar up/left/right/down satır düzenini izler; bu görseller ayrı `ASSET_LICENSE.md` kapsamındaki CC0 1.0 varlık lisansına dahildir.
- **Box Cutter silah görseli (29 Eylül 2026):** `assets/generated/weapons/box_cutter.png` mağaza ikonu, envanter görseli ve kısa saldırı animasyonu için OpenAI ImageGen ile özgün olarak üretildi. Görsel ayrı `ASSET_LICENSE.md` kapsamındaki CC0 1.0 lisansına dahildir.
- **Yönlü yeni düşman animasyonları:** Scanline Runner, Cooler Dripper, Coupon Tosser, Pallet Jack Pusher ve Night-Shift Supervisor için dört yöne bakan dörder kareli yürüyüş atlasları OpenAI ImageGen ile 27 Eylül 2026'da özgün olarak üretilmiştir (`assets/generated/actors/enemy_*_walk.png`). Bu görseller ayrı `ASSET_LICENSE.md` dosyasındaki CC0 1.0 varlık lisansına dahildir.

---

## 3. Ses Varlıkları

`assets/audio/` altındaki WAV dosyaları proje için sentezlenmiştir ve `ASSET_LICENSE.md` kapsamındaki CC0 1.0 varlık lisansına dahildir. `generate_audio.py` kaynak kodudur ve MIT lisanslı proje koduyla aynı lisansa tabidir.

---

## 4. Oyun Motoru

- **Godot Engine:** [godotengine.org](https://godotengine.org) (MIT Lisansı)
- Copyright (c) 2014-present Godot Engine contributors.
- Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

---

## 5. Proje Lisansı

Oyunun tüm kaynak kodu MIT Lisansı altındadır:
- **Telif Hakkı:** Copyright (c) 2026 Asrın Kılıç (dixtuel)
- Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.
