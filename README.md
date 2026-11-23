# SIHAMA

SIHAMA adalah prototipe Flutter untuk melaporkan hama dan penyakit tanaman,
meninjau laporan, serta melihat dan mengelola produk pertanian. Antarmukanya
mendukung tiga peran: Pelapor, Penyuluh, dan Mitra Toko.

## Peran demo

Pada layar awal, pilih peran lalu masuk atau beralih ke formulir pendaftaran.
Kredensial demo telah terisi untuk setiap peran. Email yang valid dan kata
sandi minimal enam karakter dapat digunakan untuk masuk ke demo lokal. Login
dan pendaftaran tetap berupa alur demo lokal; pemilihan dokumen memakai contoh
lokal dan tidak mengunggah berkas ke server.

## Data lokal

Aplikasi Android menyimpan data di basis data SQLite lokal menggunakan
`sqflite`. Data tersimpan di perangkat dan tidak disinkronkan ke server.

Aplikasi mendukung operasi buat, baca, ubah, dan hapus untuk:

- **Laporan tanaman:** Pelapor dapat mengirim laporan melalui **Buat Laporan
  Sekarang**, melihat laporan melalui **Laporan**, serta mengubah atau
  menghapusnya dari menu laporan. Penyuluh dapat meninjau antrean laporan
  lokal yang sama.
- **Produk AgriMarket:** Mitra Toko dapat membuat produk melalui **Tambah
  produk**, lalu menggunakan menu produk untuk mengubah atau menghapus nama,
  kategori, harga, dan stok. Pelapor dapat mengisi keranjang, membuat pesanan,
  dan mengurangi stok yang tersedia.
- **Profil petani:** Buat profil jika belum tersedia, ubah melalui **Profil**,
  atau hapus dari layar profil.
- **Pesanan dan percakapan:** Pesanan baru serta pesan dengan penyuluh disimpan
  di SQLite lokal pada perangkat.

Data contoh laporan, produk, dan profil dimasukkan saat basis data pertama kali
dibuat. Pesanan contoh, referensi penyakit, serta notifikasi masih merupakan
data demo; transaksi pesanan dan percakapan yang dibuat pengguna tersimpan di
SQLite.

## Menjalankan dan menguji aplikasi

```powershell
flutter pub get
flutter run
flutter test
flutter analyze
```

## Membuat APK Android

```powershell
flutter build apk --release
```

APK rilis dengan desain yang diperbarui disalin ke
`apk_output/sihama-figma-redesign-release.apk`.
