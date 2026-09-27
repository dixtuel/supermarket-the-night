<div align="center">

# 🛒 Supermarket: The Night

**Bir mahalle süpermarketinde gece vardiyasında hayatta kalma mücadelesi.**  
*A 2D top-down rogue-lite horde-survival game set inside an eerie night-shift supermarket.*

[![Engine](https://img.shields.io/badge/Engine-Godot_4.7.2-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Code: MIT](https://img.shields.io/badge/Code-MIT-yellow.svg)](LICENSE)
[![Assets: CC0](https://img.shields.io/badge/Assets-CC0_1.0-blue.svg)](ASSET_LICENSE.md)
[![itch.io](https://img.shields.io/badge/itch.io-Supermarket%3A%20The%20Night-FA5C5C?logo=itchdotio&logoColor=white)](https://dixtuel.itch.io/supermarket-the-night)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20Android-blue)](https://dixtuel.itch.io/supermarket-the-night)
[![Status](https://img.shields.io/badge/Version-0.2.0--alpha-success)](#)

<br/>

### 🎮 [Oyunu itch.io Üzerinden Oyna & İndir](https://dixtuel.itch.io/supermarket-the-night)

</div>

---

## 📖 Genel Bakış / Overview

**Supermarket: The Night**, gece yarısı kepenkleri kapanan bir süpermarkette tek başına çalışan bir reyon görevlisinin hayatta kalma hikayesidir. Gece ilerledikçe rafların arasından beliren açgözlü yaratıklar, agresif alışveriş arabaları ve tuhaf market mutantlarına karşı temizlik malzemeleri, etiket tabancaları ve fırlatılabilir konserve kutularıyla mücadele et!

20 turluk ana vardiya kampanyasını tamamla veya **Endless Night** modunda sabah ışıklarını görene kadar diren.

---

## ✨ Temel Özellikler / Key Features

- **4 Birbiriyle Bağlantılı Dinamik Oda:**
  - **Market (Ana Salon):** Soğutucular, 5 geniş reyon, manav kasaları ve kasa bankosu.
  - **Depo (Depot):** Palet yığınları, çuvallar, yedek malzeme konsolu ve bilgisayarlı çalışma istasyonu.
  - **Tuvalet (Restroom):** Kabinler, temizlik dolapları ve lavabolar.
  - **Yönetici Ofisi (Manager Office):** Çelik kasa, dosya dolapları, deri koltuk ve yönetici masası.
- **Dinamik Dalgalar & Elit Düşmanlar:**
  - Oyuncunun silahlarına, seviyesine ve kullandığı yeteneklere göre dalga kompozisyonu ve zorluk çarpanı dinamik olarak ölçeklenir.
  - 5, 10, 15 ve 20. dalgalarda özel elit düşmanlar ve bölüm sonu canavarı.
- **Vardiya Mağazası (Shift Shop):**
  - Tur aralarında kazanılan primlerle yeni silahlar, pasif stat güçlendirmeleri ve tüketilebilirler satın alma.
  - Satın alınan yuva kilitleme ve yeniden çevirme (reroll) mekaniği.
- **Kusursuz Piksel Hitbox Desteği:**
  - Tüm mobilya, koli, raf ve duvarların zemin temas noktaları milimetrik olarak modellenmiştir; yürüyüş yolları ve kapı geçişleri tamamen akıcıdır.
- **Gelişmiş Görüntü & Çoklu Çözünürlük:**
  - Native 1080p (1920x1080), 900p, 768p ve 720p tam ekran / kenarlıksız pencere modları.
  - Bulanıklığı önleyen MSDF yazı tipi renderlaması ve piksel hizalama.
- **Tam Yerelleştirme & Vardiya Kayıt Sistemi:**
  - Türkçe ve İngilizce anında dil değiştirme desteği.
  - "Kaydet ve Çık" ile yarım kalan vardiyanızı dilediğiniz an sürdürebilme.

---

## 🕹️ Kontroller / Controls

| Tuş | Eylem (TR) | Action (EN) |
|---|---|---|
| **W, A, S, D** / **Yön Tuşları** | Hareket Et | Move |
| **Space (Boşluk)** | Atılma / Kaçınma | Dash / Dodge |
| **E / Sol Tık** | Konsol / Mağaza Etkileşimi | Interact / Shop Purchase |
| **ESC** | Duraklat / Ayarlar Menüsü | Pause / Settings Menu |
| **Fare Hareketi** | Nişan Alma (Otomatik Hedefleme Destekli) | Aim Reticle |

---

## 🛠️ Kaynak Koddan Çalıştırma ve Derleme (Build from Source)

Projeyi çalıştırmak için [Godot 4.7.2+](https://godotengine.org/download) gereklidir.

### 1. Depoyu Klonlayın
```bash
git clone https://github.com/dixtuel/supermarket-the-night.git
cd supermarket-the-night
```

### 2. Godot ile Çalıştırın
```bash
godot --path .
```

### 3. Dışa Aktarım (Export Builds)
```bash
mkdir -p builds/linux builds/windows
godot --headless --path . --export-release "Linux/X11" builds/linux/SupermarketTheNight.x86_64
godot --headless --path . --export-release "Windows Desktop" builds/windows/SupermarketTheNight.exe
```

---

## 📂 Proje Mimarisi / Directory Structure

```text
├── assets/             # Grafikler, sesler, fontlar ve özgün çizimler
│   ├── generated/      # Oda arka planları ve mağaza ikonları
│   ├── ui_pack/        # Arayüz ve font varlıkları (Kenney CC0)
│   └── top_down_shooter/ # Karakter ve zemin sprite'ları (Kenney CC0)
├── combat/             # Silah kontrolü, mermiler ve hasar formülleri
├── data/               # Dalga, yükseltme, ses ve yerelleştirme (I18n) verileri
├── entities/           # Oyuncu, düşman aktörleri ve yardımcı personeller
├── levels/             # Ana arena, oda geçişleri ve oda sahneleri
│   ├── arena/          # Dalga akışı, spawn döngüsü ve oyun alanı
│   └── rooms/          # Market, Depo, Tuvalet ve Ofis sahneleri
├── progression/        # XP küreleri, iksirler ve ganimetler
└── ui/                 # HUD, mağaza, duraklatma, ayarlar ve jenerik (credits)
```

---

## 👥 Emeği Geçenler / Credits & Attribution

- **Yapımcı & Geliştirici:** Asrın Kılıç ([dixtuel](https://github.com/dixtuel))
- **Fikir & Tasarım Katkısı:** kiyici + I3aN.Ka!
- **Oyun Motoru:** [Godot Engine](https://godotengine.org) (MIT)
- **Görsel Üretim:** OpenAI Image 2.5
- **Açık Kaynak Varlıklar:** [Kenney](https://kenney.nl) (CC0 1.0 Universal) — Detaylı liste için [ATTRIBUTION.md](ATTRIBUTION.md) dosyasına bakabilirsiniz.
- **Debug & Destek:** ChatGPT Codex, Google Gemini

---

## 📄 Lisans / License

Bu projenin kaynak kodu **MIT Lisansı** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.

Copyright (c) 2026 **Asrın Kılıç (dixtuel)**.
