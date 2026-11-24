# SIHAMA

SIHAMA is a Flutter prototype for reporting crop pests and diseases, reviewing
reports, and browsing or managing agricultural products. The interface follows
the role-based SIHAMA prototype for Pelapor, Penyuluh, and Mitra Toko.

## Demo roles

The opening screen lets you select a role and sign in or switch to the
registration form. Demo credentials are prefilled for each role; any valid
email and password of at least six characters can enter the local demo. Login,
registration, document selection, notifications, and sample order records are
not connected to a server.

## Local CRUD data

The Android app stores data in a local SQLite database using `sqflite`. Data is
kept on the device and is not synchronized to a server.

The app supports local data operations for:

- Crop reports: Pelapor can submit from **Buat Laporan Sekarang**, review from
  **Laporan**, and use the report menu to edit or delete. Penyuluh can review
  the same local report queue. New reports omit commodity selection; one or
  more symptoms can be selected from a searchable picker. Report photos accept
  PNG, JPG, and JPEG files up to 5 MB and are stored as bytes with the report.
- AgriMarket products: Mitra Toko can use **Tambah produk** to create products
  and each product menu to edit or delete name, category, price, and stock.
- Shop orders: Pelapor can check out products after a report is reviewed.
  Orders and stock deductions are committed together in SQLite; Mitra Toko can
  progress orders from **Dipesan** to **Diproses**, **Dikirim**, and **Selesai**,
  or cancel an early order and return its stock.
- Farmer profile: create a profile when none exists, edit it from **Profil**,
  or delete it from the profile screen.

Example reports, products, profiles, and shop orders are inserted when the
database is first created. Adviser reference entries and sample notification
messages remain prototype-only and are not stored in SQLite.

## Run and test

```powershell
flutter pub get
flutter run
flutter test
flutter analyze
```

## Build Android APK

```powershell
flutter build apk --release
```

The redesigned release APK is copied to
`apk_output/sihama-figma-redesign-release.apk`.
