# Menyiapkan Supabase SIHAMA

1. Di Supabase Dashboard, buka **SQL Editor** dan jalankan seluruh isi `schema.sql`.
2. Jalankan seluruh isi `seed.sql` untuk memasukkan 79 referensi diagnosis dan empat produk awal.
3. Jalankan `migrations/20261126_align_sihama_erd.sql` untuk menambahkan relasi gejala, penyakit, item pesanan, profil khusus peran, notifikasi, dan relasi pesanan ke laporan. Migrasi ini aditif dan mempertahankan kolom lama agar data historis tetap terbaca.
4. Buat akun pelapor melalui aplikasi. Jika konfirmasi email aktif, konfirmasi email sebelum masuk.
5. Buat akun penyuluh dan mitra toko melalui **Authentication → Users → Add user**. Salin UUID pengguna, lalu jalankan perintah yang sesuai di SQL Editor:

   ```sql
   update public.farmer_profiles
   set access_role = 'penyuluh'
   where user_id = 'UUID-PENGGUNA';
   ```

   Gunakan `mitra_toko` untuk akun mitra. Akun tidak dapat menaikkan perannya sendiri dari aplikasi.
6. Jalankan aplikasi Android. Perubahan data memerlukan koneksi internet.

`main.dart` menginisialisasi Supabase dengan URL dan publishable key. Publishable key memang berada di aplikasi klien; kebijakan RLS pada `schema.sql` membatasi akses. Jangan pernah memasukkan `service_role` key atau password database ke aplikasi.

Data lokal yang sudah tersimpan di SQLite tidak otomatis berpindah ke Supabase. Seed hanya berisi referensi diagnosis dan produk awal; laporan dan pesanan demo tidak disalin. Pesanan lama tanpa laporan terkait tetap memiliki `report_id` kosong; pesanan baru melalui aplikasi harus memilih laporan berstatus **Selesai Ditinjau**.
