# Supermarket: The Night — v0.1.4-alpha (Geliştirici Notları / Release Notes)

Bu sürümde tüm odaların fiziksel sınırları ve çarpışma (hitbox) alanları oyun içi hassasiyetle elden geçirildi, ayrıca depodaki konsoldan çağrılan vardiya yardımcısı (help vehicle) tamamen düzeltildi ve geliştirildi.

### 📌 v0.1.4-alpha Yenilikleri ve Düzeltmeler:

- **Vardiya Destek Aracı (Temporary Shift Helper) Düzeltmeleri:**
  - **Kompakt Boyut:** Depodaki tedarik konsolundan çağrılan yardım aracının devasa (ekranı kaplayan) boyutu düzeltildi, oyuncu boyutlarıyla uyumlu kompakt bir ölçeğe (`0.22`) çekildi.
  - **Belirgin Ateş ve Geri Tepme Efektleri:** Aracın ateş ettiği net şekilde anlaşılsın diye parlak neon camgöbeği (cyan) enerji mermileri ve her atışta fiziksel geri tepme (squash & stretch) animasyonu eklendi.
  - **Oda Geçiş Takibi (`snap_to_owner`):** Oyuncu odalar arasında (Market, Depo, Tuvalet, Ofis) geçiş yaptığında aracın eski odada boşlukta takılı kalması engellendi; oyuncuyla birlikte yeni odaya anında ışınlanması sağlandı.
  - **Saldırı Doğrulaması:** Hedefleme, menzil tarama ve düşmanlara hasar verme/yok etme döngüsü test edilip onaylandı.

- **Milimetrik Harita & Oda Hitbox Düzenlemeleri:**
  - **Ana Market:**
    - Alt kapı ve duvar geçişleri genişletildi, takılmalar giderildi.
    - 5. raf ile kasa arasındaki koridor geçişi açıldı.
    - Depoya açılan kapı pervazı ve sağ tarafındaki fazladan genişlik temizlendi.
    - Reyonlar, manav kasaları ve kasa çevresi milimetrik olarak optimize edildi.
  - **Depo (Depot):**
    - Ortadaki depo raflarının genişlikleri ve koridor boşlukları yürüme akışına göre ayarlandı.
    - Sol üst transpalet ve koli hatları görsel sınırlarına tam oturtuldu.
  - **Tuvalet & Yönetici Ofisi:**
    - Kabinler, koltuklar, masalar ve kapı geçiş portalları optimize edildi.

- **Derleme & Platform:**
  - Linux x86_64 ve Windows Desktop (x64) release paketleri güncellendi.
  - Butler ile resmi alpha kanallarına (`linux-alpha`, `windows-alpha`) `0.1.4-alpha` sürümüyle yüklendi.

---
Yapımcı: dixtuel  
Fikir Verenler: kiyici + I3aN.Ka!  
Motor: Godot 4.7.2  
Görsel Üretimi: OpenAI Image 2.5  
Debug Team: ChatGPT Codex, Google Gemini  
Lisans: MIT (Kod) / Kenney CC0 (Assetler)
