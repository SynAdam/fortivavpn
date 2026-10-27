// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class SId extends S {
  SId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'Tidak terhubung';

  @override
  String get statusConnecting => 'Menghubungkan';

  @override
  String get statusConnected => 'Terhubung';

  @override
  String get statusDisconnecting => 'Memutuskan...';

  @override
  String get statusError => 'Kesalahan';

  @override
  String get statusVerifying => 'Memverifikasi...';

  @override
  String get disconnect => 'Putuskan';

  @override
  String get connectBtn => 'Hubungkan';

  @override
  String get disconnectBtn => 'Putuskan';

  @override
  String get pleaseWait => 'HARAP TUNGGU';

  @override
  String get locationLabel => 'Lokasi';

  @override
  String get selectServer => 'Pilih lokasi';

  @override
  String get serverLocation => 'Lokasi';

  @override
  String get searchServers => 'Cari server';

  @override
  String get locationsTitle => 'Lokasi';

  @override
  String get sortLatency => 'Urutkan: Latensi';

  @override
  String get sortAZ => 'Urutkan: A-Z';

  @override
  String get sortedByLatency => 'Diurutkan berdasarkan latensi';

  @override
  String get sortedAZ => 'Diurutkan A-Z';

  @override
  String get pingAll => 'Uji semua';

  @override
  String get pinging => 'Melakukan ping...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Hentikan';

  @override
  String get fastestServer => 'Tercepat';

  @override
  String get timeout => 'waktu habis';

  @override
  String get tabCommunity => 'Komunitas';

  @override
  String get tabFree => 'Gratis';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Belum ada server komunitas';

  @override
  String get communityLoadFailed => 'Tidak dapat memuat daftar ini';

  @override
  String get communityRetry => 'Coba lagi';

  @override
  String get officialTabExplainer =>
      'Dijalankan oleh Fortiva dan kami jaga agar tetap online. Dipakai bersama oleh semua pengguna aplikasi. Mulai dari sini.';

  @override
  String get communityTabExplainer =>
      'Pilihan koneksi tambahan. Kecepatan dan ketersediaannya bervariasi.';

  @override
  String get noFreeServers => 'Belum ada server gratis';

  @override
  String get noPremiumServers => 'Belum ada server premium';

  @override
  String noResultsFor(String query) {
    return 'Tidak ada hasil untuk \"$query\"';
  }

  @override
  String get proBadge => 'PREMIUM';

  @override
  String get freeBadge => 'GRATIS';

  @override
  String get settings => 'Pengaturan';

  @override
  String get connection => 'Jaringan';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Gunakan server DNS Anda sendiri';

  @override
  String get about => 'Tentang';

  @override
  String get privacyPolicy => 'Kebijakan Privasi';

  @override
  String get contactUs => 'Hubungi Kami';

  @override
  String get rateOnGooglePlay => 'Beri nilai Fortiva di Google Play';

  @override
  String get website => 'Situs web';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Versi';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSubtitle => 'Bahasa antarmuka';

  @override
  String get whatIsDns => 'Apa itu DNS?';

  @override
  String get dnsExplanation =>
      'DNS mengubah nama situs web menjadi alamat yang bisa dijangkau ponsel Anda. Memakai DNS lain dapat membuat situs lebih cepat dimuat dan membantu menjangkau situs yang diblokir penyedia internet Anda.';

  @override
  String get configuration => 'Pengaturan';

  @override
  String get primaryDns => 'DNS utama';

  @override
  String get primaryDnsHint => 'Bawaan: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS sekunder (opsional)';

  @override
  String get secondaryDnsHint => 'Bawaan: 8.8.8.8';

  @override
  String get saveConfiguration => 'Simpan';

  @override
  String get dnsSaved => 'Pengaturan DNS disimpan';

  @override
  String get invalidPrimaryDns => 'Alamat DNS utama itu tidak valid';

  @override
  String get invalidSecondaryDns => 'Alamat DNS sekunder itu tidak valid';

  @override
  String get statistics => 'Riwayat';

  @override
  String get overview => 'RINGKASAN';

  @override
  String get connectionsLabel => 'Sesi';

  @override
  String get totalTime => 'Waktu terhubung';

  @override
  String get dataUsage => 'Data terpakai';

  @override
  String get uploaded => 'Diunggah';

  @override
  String get downloaded => 'Diunduh';

  @override
  String get total => 'Jumlah';

  @override
  String lastUpdated(String date) {
    return 'Terakhir diperbarui: $date';
  }

  @override
  String today(String time) {
    return 'Hari ini pukul $time';
  }

  @override
  String get yesterday => 'Kemarin';

  @override
  String daysAgo(int count) {
    return '$count hari yang lalu';
  }

  @override
  String get noDataYet => 'Belum ada data sesi';

  @override
  String get connectToStart => 'Hubungkan untuk mulai mencatat';

  @override
  String get errorConnectionFailed => 'Tidak dapat terhubung';

  @override
  String get errorServerNotWorking =>
      'Lokasi ini tidak berfungsi. Coba lokasi lain.';

  @override
  String get errorServerNotForwarding =>
      'Lokasi ini tidak meneruskan lalu lintas. Coba lokasi lain.';

  @override
  String get errorUnexpected => 'Kesalahan tak terduga';

  @override
  String get errorDisconnectionFailed => 'Tidak dapat memutuskan koneksi';

  @override
  String get errorFailedToRegister => 'Gagal mendaftarkan perangkat';

  @override
  String get ipInformation => 'Periksa IP saya';

  @override
  String get connectionAnalytics => 'Riwayat';

  @override
  String get recentSessions => 'Koneksi terbaru';

  @override
  String get speedTest => 'Uji kecepatan';

  @override
  String get startTest => 'JALANKAN DIAGNOSTIK';

  @override
  String get download => 'Unduh';

  @override
  String get upload => 'Unggah';

  @override
  String get testingViaVpn => 'Menguji lewat tunnel';

  @override
  String get testingDirect => 'Menguji koneksi langsung';

  @override
  String get splitTunneling => 'Konfigurasi Rute';

  @override
  String get splitTunnelingDescription =>
      'Pilih kategori aplikasi yang tidak melalui tunnel. Aplikasi yang dikecualikan memakai koneksi jaringan langsung Anda.';

  @override
  String get enableSplitTunneling => 'Aktifkan Pemisahan Rute';

  @override
  String get splitTunnelActive => 'Aplikasi terpilih tidak melalui tunnel';

  @override
  String get splitTunnelInactive => 'Semua lalu lintas melalui tunnel';

  @override
  String get bypassVpnFor => 'Tanpa tunnel untuk';

  @override
  String get tools => 'Diagnostik';

  @override
  String get settingsGeneral => 'Umum';

  @override
  String get shareDiagnosticsTitle => 'Bagikan diagnostik koneksi';

  @override
  String get shareDiagnosticsBody =>
      'Mengirim laporan koneksi, operator dan negara Anda, model ponsel dan versi Android, nama situs yang Anda buka lewat VPN beserta jumlah hariannya, serta apakah Anda melihat atau mengetuk pesan, penawaran Premium, dan kartu undangan kami. Kami tidak pernah melihat halaman yang Anda buka atau apa yang Anda kirim.';

  @override
  String get security => 'Kepatuhan';

  @override
  String get privacyDashboard => 'Analisis Endpoint';

  @override
  String get privacyDashboardSubtitle =>
      'Transparansi IP & pemantauan kebocoran';

  @override
  String get connectionAnalyticsSubtitle => 'Riwayat sesi & laporan';

  @override
  String get speedTestSubtitle => 'Pengukuran kecepatan transfer';

  @override
  String get splitTunnelingSubtitle => 'Atur kebijakan rute';

  @override
  String get splashTagline => 'Akses pribadi, di mana pun Anda berada';

  @override
  String get openSourceLicence => 'Lisensi sumber terbuka';

  @override
  String get sourceOfferTitle => 'Lisensi sumber terbuka';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN adalah perangkat lunak bebas di bawah GNU General Public License v3. Aplikasi ini dibangun di atas Xray-core dan proyek sumber terbuka lainnya.\n\nAnda berhak mendapatkan kode sumber lengkap untuk versi yang Anda pasang. Untuk memintanya, kirim email ke admin@fortivavpn.com dengan menyebutkan versi aplikasi Anda. Penawaran ini berlaku selama tiga tahun sejak tanggal Anda menerima versi ini.';

  @override
  String get close => 'Tutup';

  @override
  String get account => 'Akun';

  @override
  String get deleteAccount => 'Hapus akun';

  @override
  String get deleteAccountSubtitle =>
      'Hapus perangkat ini dan data Anda secara permanen';

  @override
  String get deleteAccountConfirmTitle => 'Hapus akun Anda?';

  @override
  String get deleteAccountConfirmBody =>
      'Ini akan menghapus pendaftaran perangkat Anda, server pribadi yang dibuat untuk Anda, dan pesan Anda di chat dukungan. Riwayat koneksi di ponsel ini juga dihapus.\n\nTindakan ini tidak bisa dibatalkan. Anda bisa mulai lagi kapan saja dengan membuka kembali aplikasi.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari',
    );
    return 'Catatan akun Anda langsung dihapus. Salinan di cadangan dan log server anonim dibersihkan dalam $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Catatan akun Anda langsung dihapus. Salinan di cadangan dan log server anonim dibersihkan kemudian, sesuai jadwal dalam kebijakan privasi kami.';

  @override
  String get deleteAccountCancel => 'Pertahankan akun saya';

  @override
  String get deleteAccountConfirm => 'Hapus';

  @override
  String get deleteAccountInProgress => 'Menghapus akun Anda';

  @override
  String get deleteAccountDone => 'Akun Anda telah dihapus.';

  @override
  String get deleteAccountFailed =>
      'Tidak dapat menghapus akun Anda. Periksa koneksi Anda dan coba lagi.';

  @override
  String get homeTapToConnect => 'Ketuk untuk menghubungkan';

  @override
  String get homeChecking => 'Memeriksa koneksi';

  @override
  String get homePreparing => 'Menyiapkan server Anda';

  @override
  String get homeDisconnecting => 'Memutuskan koneksi';

  @override
  String get homeFindingPath => 'Mencari jalur';

  @override
  String get diagCheckingInternet => 'Memeriksa internet Anda';

  @override
  String get diagInternationalCut =>
      'Internet internasional terputus di jaringan ini';

  @override
  String diagPathRow(String city, int n) {
    return '$city, jalur $n';
  }

  @override
  String get diagOpen => 'terbuka';

  @override
  String get diagBlocked => 'diblokir';

  @override
  String get diagSkipped => 'dilewati hari ini';

  @override
  String diagConnectingThrough(String city) {
    return 'Menghubungkan lewat $city';
  }

  @override
  String get diagVerifying => 'Memverifikasi lalu lintas';

  @override
  String get diagNoInternet =>
      'Ponsel Anda sedang tidak terhubung ke internet.';

  @override
  String get diagCutOff =>
      'Jaringan Anda sedang tidak bisa menjangkau internet internasional. Ketuk untuk mencoba lagi.';

  @override
  String get diagNothingOpen =>
      'Semua jalur sedang diblokir. Ketuk untuk mencoba lagi.';

  @override
  String get homeTryingAgain =>
      'Semua jalur sedang diblokir. Kami akan mencoba lagi sebentar lagi.';

  @override
  String get homeCutOffTryingAgain =>
      'Jaringan Anda sedang tidak bisa menjangkau internet internasional. Kami akan mencoba lagi sebentar lagi.';

  @override
  String get homeOfflineTryingAgain =>
      'Ponsel Anda sedang tidak terhubung ke internet. Kami akan mencoba lagi sebentar lagi.';

  @override
  String get diagPathFailed =>
      'Jalurnya terbuka, tetapi tunnel tidak terbentuk. Ketuk untuk mencoba lagi.';

  @override
  String get openVpnSettings => 'Buka pengaturan VPN';

  @override
  String get yourServer => 'SERVER ANDA';

  @override
  String get yourServerCaption =>
      'Milik Anda sendiri. Tidak ada orang lain yang terhubung lewat server ini.';

  @override
  String get ourServer => 'SERVER KAMI';

  @override
  String get ourServerCaption =>
      'Dijalankan oleh Fortiva dan dipakai bersama semua orang. Digunakan sampai server Anda sendiri siap.';

  @override
  String get communityServer => 'SERVER KOMUNITAS';

  @override
  String get communityServerCaption =>
      'Pilihan koneksi tambahan. Bisa berhenti bekerja kapan saja.';

  @override
  String communityServerNumber(String n) {
    return 'Server komunitas $n';
  }

  @override
  String get myServersTitle => 'Server Anda';

  @override
  String get myServersExplainer =>
      'Setiap perangkat Fortiva mendapat server sendiri di setiap lokasi, dengan kredensial yang hanya milik pemasangan ini. Tidak perlu akun.';

  @override
  String get myServersInUse => 'Sedang dipakai';

  @override
  String get myServersEmpty => 'Belum ada server yang ditetapkan';

  @override
  String get myServersRetry => 'Coba lagi';

  @override
  String get myServersBlockedTitle => 'Anda sudah memakai data hari ini';

  @override
  String get myServersBlockedWait =>
      'Kuota harian Anda direset secara otomatis. Cek lagi nanti.';

  @override
  String myServersMoved(String place) {
    return 'Sekarang memakai $place';
  }

  @override
  String get copyLink => 'Salin tautan';

  @override
  String get linkCopied => 'Tautan disalin';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used dari $limit terpakai hari ini';
  }

  @override
  String get quotaUsedUp => 'Data harian sudah habis';

  @override
  String get quotaUnlimited => 'Data tanpa batas';

  @override
  String get quotaDaily => 'Data harian';

  @override
  String get quotaLimitReached => 'Batas harian tercapai';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left dari $limit tersisa';
  }

  @override
  String get quotaResetsShortly => 'Direset sebentar lagi';

  @override
  String quotaResetsInHours(int hours) {
    return 'Direset dalam $hours jam';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Direset dalam $minutes mnt';
  }

  @override
  String get myServersSubtitle => 'Server yang disediakan untuk perangkat ini';

  @override
  String get sharedServersTitle => 'Server bersama';

  @override
  String get sharedServersSubtitle => 'Lokasi publik, dipakai sebagai cadangan';

  @override
  String get tabOfficial => 'Server kami';

  @override
  String get noOfficialServers => 'Tidak ada server Fortiva saat ini';

  @override
  String get inviteTitle => 'Undang teman';

  @override
  String get inviteSubtitle => 'Dapatkan data harian tambahan';

  @override
  String get inviteYourCode => 'Kode undangan Anda';

  @override
  String get inviteShareAction => 'Bagikan undangan';

  @override
  String get inviteCopyAction => 'Salin kode';

  @override
  String get inviteCodeCopied => 'Kode disalin';

  @override
  String inviteShareMessage(String code, String url) {
    return 'VPN gratis yang lancar buat aku: Fortiva. Tanpa daftar.\nPasang dari tautan ini:\n$url\nKode undanganku: $code';
  }

  @override
  String get inviteHowItWorks => 'Cara kerjanya';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari yang berbeda',
    );
    return 'Bagikan kode Anda. Saat seseorang memasang aplikasi, memasukkan kode itu, dan memakai VPN pada $_temp0, Anda mendapat $amount tambahan pada data harian Anda. Tambahan ini tetap ada di akun Anda.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari yang berbeda',
    );
    return 'Bagikan kode Anda. Saat seseorang memasang aplikasi, memasukkan kode itu, dan memakai VPN pada $_temp0, Anda mendapat lebih banyak data setiap hari. Tambahan ini tetap ada di akun Anda.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Bagikan kode Anda. Saat seseorang memasang aplikasi, memasukkan kode itu, dan memakai VPN selama beberapa waktu, Anda mendapat $amount tambahan pada data harian Anda. Tambahan ini tetap ada di akun Anda.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Bagikan kode Anda. Saat seseorang memasang aplikasi, memasukkan kode itu, dan memakai VPN selama beberapa waktu, Anda mendapat lebih banyak data setiap hari. Tambahan ini tetap ada di akun Anda.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Anda bisa mendapat hingga $max per hari dari undangan.';
  }

  @override
  String get inviteStatInvited => 'Diundang';

  @override
  String get inviteStatEarning => 'Memenuhi syarat';

  @override
  String get inviteStatBonus => 'Data bonus';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount setiap hari';
  }

  @override
  String get inviteNoBonusYet => 'Belum ada bonus';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan belum memenuhi syarat',
      one: '1 undangan belum memenuhi syarat',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Anda bergabung dengan kode $code';
  }

  @override
  String get inviteLoadFailed => 'Tidak dapat memuat kode undangan Anda';

  @override
  String get inviteRetry => 'Coba lagi';

  @override
  String get inviteHaveCodeTitle => 'Punya kode undangan?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Masukkan dalam $hours jam pertama',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Masukkan segera setelah memasang';

  @override
  String get inviteEnterCodeHint => 'Kode undangan';

  @override
  String get inviteApplyAction => 'Terapkan';

  @override
  String get inviteNotNowAction => 'Nanti saja';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari yang berbeda',
    );
    return 'Undangan diterima. Teman Anda mendapat data bonus setelah Anda memakai VPN pada $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Undangan diterima. Teman Anda mendapat data bonus setelah Anda memakai VPN selama beberapa waktu.';

  @override
  String get inviteClaimAlready => 'Perangkat ini sudah memakai kode undangan';

  @override
  String get inviteClaimRejected =>
      'Kode itu tidak berfungsi. Periksa dan coba lagi';

  @override
  String get inviteClaimNetwork => 'Tidak dapat menjangkau server. Coba lagi';

  @override
  String get inviteCardTitle => 'Fortiva lancar buat kamu? Kirim ke temanmu';

  @override
  String get inviteCardBody =>
      'Kirim tautan pemasangan ke temanmu supaya dia juga bisa terhubung gratis.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Saat temanmu mulai memakai Fortiva, kamu mendapat Premium selama $days hari.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Saat temanmu mulai memakai Fortiva, kamu mendapat hadiah Premium.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Salin tautan';

  @override
  String get inviteOtherApps => 'Aplikasi lain';

  @override
  String get inviteLinkCopied => 'Pesan undangan disalin';

  @override
  String get invitePasteBody =>
      'Salin kode dari pesan teman Anda, lalu tempel di sini.';

  @override
  String get invitePasteAction => 'Tempel';

  @override
  String get inviteErrorTooLate =>
      'Waktu untuk memasukkan kode undangan di ponsel ini sudah habis.';

  @override
  String get inviteErrorUnknown =>
      'Kode ini tidak ditemukan. Salin lagi dari pesan teman Anda.';

  @override
  String get inviteErrorOwnCode =>
      'Ini kode Anda sendiri. Masukkan kode teman Anda.';

  @override
  String get inviteErrorMutual =>
      'Anda dan teman Anda tidak bisa saling mengundang.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Setiap teman yang mulai memakai Fortiva juga memberi Anda Premium selama $days hari.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Anda bisa mendapat hingga $max hari Premium dari undangan.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Bonus Anda berlaku selama teman Anda terus memakai Fortiva. Jika ada teman yang berhenti, bonus berkurang.';

  @override
  String inviteTreeNext(String amount) {
    return 'Teman Anda berikutnya menambah $amount per hari setelah mulai memakai Fortiva.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Bonus Anda tidak pernah turun di bawah $amount per hari, berkat teman yang Anda undang sebelumnya.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Slot Anda';

  @override
  String get inviteTreeSlotActive => 'Aktif';

  @override
  String get inviteTreeSlotNotActive => 'Sedang tidak aktif';

  @override
  String get inviteTreeSlotEmpty => 'Slot kosong';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount per hari sekarang';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount per hari jika keduanya aktif';
  }

  @override
  String get inviteTreeNothingYet => 'Belum ada';

  @override
  String get inviteTreeFriendsTitle => 'Lewat slot Anda';

  @override
  String get inviteTreeRowFriends => 'Di slot Anda';

  @override
  String get inviteTreeRowFriendsSlots => 'Di slot mereka';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps langkah dari Anda',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people orang',
    );
    return '$_temp0, $active aktif';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Bagikan kode Anda. $slots teman pertama yang memenuhi syarat mengisi slot Anda secara berpasangan.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Bagikan kode Anda. Teman-teman pertama yang memenuhi syarat mengisi slot Anda secara berpasangan.';

  @override
  String get inviteTreeHowPair =>
      'Pasangan memberi lebih banyak jika keduanya aktif.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Saat slot Anda sudah penuh, teman Anda berikutnya yang memenuhi syarat mengisi slot kosong berikutnya, lebih jauh dari Anda. Mereka tetap menambah data untuk Anda, makin jauh makin kecil jumlahnya.';

  @override
  String get inviteTreeHowOthers =>
      'Pasangan pertama Anda juga bisa diisi orang yang tidak Anda undang. Mereka menambah data untuk Anda dengan cara yang sama.';

  @override
  String inviteTreeHowActive(int days, int window) {
    return 'Seorang teman dihitung aktif selama ia memakai Fortiva setidaknya $days hari dalam $window hari terakhir.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Seorang teman dihitung aktif selama ia terus memakai Fortiva.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Undangan bisa menambah hingga $max per hari.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'Tambahan dari undangan punya batas harian.';

  @override
  String get premiumSourceInvite => 'Dari undangan Anda';

  @override
  String quotaBonusIncluded(String amount) {
    return 'termasuk bonus undangan $amount';
  }

  @override
  String get updateTitle => 'Pembaruan tersedia';

  @override
  String get updateRequiredTitle => 'Pembaruan diperlukan';

  @override
  String updateBody(String version) {
    return 'Fortiva $version sudah tersedia. Perbarui untuk mendapat perbaikan terbaru.';
  }

  @override
  String get updateRequiredBody =>
      'Versi ini tidak didukung lagi. Perbarui untuk terus memakai Fortiva.';

  @override
  String get updateNow => 'Perbarui';

  @override
  String get updateLater => 'Nanti';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Saluran Telegram';

  @override
  String get updateConnect => 'Hubungkan';

  @override
  String get updateConnectHint =>
      'Jika Google Play atau Telegram tidak terbuka, ketuk Hubungkan dulu.';

  @override
  String get updateConnected => 'Anda terhubung. Unduh pembaruannya sekarang.';

  @override
  String get updateReconnect => 'Tidak berhasil? Hubungkan ulang';

  @override
  String get updateDisconnect => 'Putuskan';

  @override
  String get updateDisconnectHint =>
      'Ketuk Putuskan untuk mengunduh pembaruan lewat internet biasa Anda.';

  @override
  String get updateNotCarrying =>
      'Anda terhubung, tetapi tidak ada yang lewat. Coba Hubungkan ulang, atau ketuk Putuskan untuk memakai internet biasa Anda.';

  @override
  String get diagVerdictNoInternet =>
      'Ponsel Anda tidak punya koneksi internet. Fortiva tidak bisa terhubung sampai internet kembali.';

  @override
  String get diagVerdictCutOff =>
      'Jaringan Anda sedang tidak bisa menjangkau internet internasional. Coba lagi dalam beberapa menit.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva tidak punya izin untuk menjalankan VPN, atau aplikasi VPN lain disetel selalu aktif.';

  @override
  String get diagVerdictServerUnreachable =>
      'Server ini tidak bisa dijangkau dari jaringan Anda. Server ini diblokir di sini atau sedang mati.';

  @override
  String get diagVerdictBlockedTls =>
      'Koneksi ke server ini diputus saat sedang disiapkan. Seperti itulah ciri penyaringan.';

  @override
  String get diagVerdictThrottled =>
      'Server menjawab semua pemeriksaan, tetapi tunnel tetap tidak membawa apa pun. Koneksinya sedang diperlambat.';

  @override
  String get diagCheckInternet => 'Periksa internet Anda';

  @override
  String diagTryServer(String server) {
    return 'Pencarian baru dengan $server';
  }

  @override
  String get diagTryAnotherServer => 'Coba server lain';

  @override
  String get diagDetails => 'Detail';

  @override
  String get diagDetailsHide => 'Sembunyikan detail';

  @override
  String privateDnsWarning(String host) {
    return 'DNS Pribadi aktif ($host), jadi beberapa situs mungkin tidak terbuka. Matikan DNS Pribadi di pengaturan ponsel Anda.';
  }

  @override
  String get openNetworkSettings => 'Buka pengaturan jaringan';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Titik uji · pemeriksaan terakhir $time · $open dari $total jalur terbuka';
  }

  @override
  String get messagesTooltip => 'Pesan';

  @override
  String get inboxTitle => 'Pesan';

  @override
  String get inboxEmpty => 'Tidak ada pesan saat ini.';

  @override
  String get messageClose => 'Tutup';

  @override
  String get supportTitle => 'Dukungan';

  @override
  String get supportTooltip => 'Chat dengan dukungan';

  @override
  String get supportAskAction => 'Tanya dukungan';

  @override
  String get supportContactSubtitle => 'Chat dengan kami di aplikasi';

  @override
  String get supportAutomaticNotice =>
      'Jawaban ditulis secara otomatis dan bisa saja salah.';

  @override
  String get supportStaffNotice =>
      'Jawaban otomatis sedang dimatikan. Pesan Anda akan diteruskan ke tim kami.';

  @override
  String get supportInputHint => 'Tulis pertanyaan Anda';

  @override
  String get supportInputHintTeam => 'Tulis ke tim kami';

  @override
  String get supportSend => 'Kirim';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '$remaining dari $limit pertanyaan tersisa hari ini';
  }

  @override
  String supportWaitIn(String time) {
    return 'Anda bisa bertanya lagi dalam $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours jam $minutes mnt';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes mnt';
  }

  @override
  String get supportNewConversation => 'Percakapan baru';

  @override
  String get supportSending => 'Mengirim';

  @override
  String get supportNotSent => 'Belum terkirim. Ketuk untuk mencoba lagi.';

  @override
  String get supportRateUp => 'Membantu';

  @override
  String get supportRateDown => 'Tidak membantu';

  @override
  String get supportRatedDown =>
      'Terima kasih. Tim kami akan meninjau jawaban ini.';

  @override
  String get supportTeamLabel => 'Tim Fortiva';

  @override
  String get supportUnavailable => 'Chat sedang tidak tersedia.';

  @override
  String get supportOpenTelegram => 'Kirim pesan ke kami di Telegram';

  @override
  String get supportGenericError => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String supportCodeTooLong(int max) {
    return 'Pesan Anda terlalu panjang. Batasi di bawah $max karakter.';
  }

  @override
  String get supportCodeEmpty => 'Pesan Anda kosong.';

  @override
  String get supportCodeWaitReply =>
      'Mohon tunggu jawaban untuk pertanyaan terakhir Anda.';

  @override
  String get supportCodeSlowDown =>
      'Anda mengirim pesan terlalu cepat. Mohon tunggu sebentar.';

  @override
  String get supportCodeQuotaDay =>
      'Anda sudah memakai semua pertanyaan hari ini.';

  @override
  String get supportCodePaused => 'Jawaban otomatis sedang dijeda.';

  @override
  String get supportCodeBusy =>
      'Asisten kami sedang sibuk. Silakan coba lagi dalam beberapa menit.';

  @override
  String get supportCodeGreeting =>
      'Halo! Ada yang bisa saya bantu soal Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Maaf, saya tidak mengerti. Silakan tulis pertanyaan Anda lagi.';

  @override
  String get supportCodeRedacted =>
      'Kami menghapus data pribadi dan tautan dari pesan Anda.';

  @override
  String get supportCodeRedactedEmpty =>
      'Pesan Anda hanya berisi data pribadi atau tautan, jadi tidak dikirim. Silakan jelaskan masalahnya dengan kata-kata.';

  @override
  String get supportCodeOffTopic =>
      'Saya hanya bisa membantu pertanyaan tentang cara memakai Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Mari tetap saling menghormati. Saya di sini untuk membantu Anda dengan Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'Asisten tidak bisa menjawab kali ini. Silakan coba beberapa saat lagi.';

  @override
  String get supportCodeToStaff =>
      'Terkirim ke tim kami. Balasannya akan muncul di sini.';

  @override
  String get supportCodeTicketOpened =>
      'Kami meneruskan pertanyaan Anda ke tim kami. Balasannya akan muncul di sini.';

  @override
  String get supportCodeNotSent =>
      'Pesan ini tidak dapat dikirim. Tulis lagi jika Anda masih perlu bantuan.';

  @override
  String get supportAssistantSubtitle => 'Asisten AI';

  @override
  String get supportThinkingReading => 'Membaca pertanyaan Anda';

  @override
  String get supportThinkingSearching => 'Mencari jawabannya';

  @override
  String get supportThinkingWriting => 'Menulis jawabannya';

  @override
  String get supportThinkingStill =>
      'Masih dikerjakan, terima kasih sudah menunggu';

  @override
  String get supportSuggestConnect => 'Saya tidak bisa terhubung';

  @override
  String get supportSuggestData => 'Berapa data saya hari ini?';

  @override
  String get supportSuggestSlow => 'Koneksi saya lambat';

  @override
  String get supportWithTeam => 'Percakapan ini sekarang ditangani tim kami.';

  @override
  String get supportTryAgainSoon => 'Coba lagi dalam beberapa menit.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours jam';
  }

  @override
  String get supportUnreadReply => 'Balasan baru';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Data tanpa batas, tanpa batas harian';

  @override
  String get premiumTileActive => 'Premium aktif';

  @override
  String get premiumGetUnlimited => 'Dapatkan tanpa batas';

  @override
  String get premiumHeadline => 'Dapatkan data tanpa batas';

  @override
  String get premiumPitch =>
      'Premium menghilangkan batas harian, jadi Anda bisa memakai data sebanyak yang Anda mau sampai Premium berakhir.';

  @override
  String get premiumActiveTitle => 'Premium aktif';

  @override
  String premiumActiveUntil(String date) {
    return 'Data tanpa batas sampai $date';
  }

  @override
  String get premiumActiveNoDate => 'Data tanpa batas';

  @override
  String get premiumRenews => 'Diperpanjang otomatis lewat Google Play';

  @override
  String get premiumSourceKey => 'Diaktifkan dengan kunci';

  @override
  String get premiumSourceCrypto => 'Dibayar dengan kripto';

  @override
  String get premiumSourceStars => 'Dibayar dengan Bintang Telegram';

  @override
  String get premiumSourceGooglePlay => 'Dibayar lewat Google Play';

  @override
  String get premiumSourceManual => 'Hadiah dari tim Fortiva';

  @override
  String get premiumYourKey => 'Kunci Anda';

  @override
  String get premiumKeyHint =>
      'Simpan kunci ini baik-baik. Masukkan di ponsel lain untuk memindahkan Premium ke sana.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hingga $count kali',
      one: 'sekali',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari',
    );
    return 'Kunci bisa dipindahkan ke ponsel lain $_temp0 dalam $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Kunci hanya bisa dipindahkan ke ponsel lain dalam jumlah terbatas.';

  @override
  String get premiumCopy => 'Salin';

  @override
  String get premiumCopied => 'Disalin';

  @override
  String get premiumChoosePlan => 'Pilih paket';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari data tanpa batas',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Data tanpa batas';

  @override
  String get premiumBuy => 'Beli';

  @override
  String get premiumPlayUnavailable =>
      'Google Play sedang tidak tersedia. Coba lagi nanti.';

  @override
  String get premiumPlayPending =>
      'Pembayaran Anda masih tertunda di Google Play. Premium dimulai begitu pembayaran disetujui.';

  @override
  String get premiumPlayConfirming => 'Mengonfirmasi pembelian Anda...';

  @override
  String get premiumPlayRetrying =>
      'Pembayaran Anda berhasil, tetapi kami belum bisa mengonfirmasinya. Kami akan terus mencoba, jadi Anda tidak perlu membayar lagi.';

  @override
  String get premiumPlayRefused =>
      'Kami tidak dapat mengonfirmasi pembelian ini. Jika Anda sudah ditagih, hubungi dukungan.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium sedang tidak tersedia di ponsel ini. Jika Anda sudah ditagih, hubungi dukungan.';

  @override
  String get premiumNotAvailable =>
      'Premium sedang tidak tersedia di ponsel ini.';

  @override
  String get premiumPlayFailed => 'Pembelian tidak berhasil. Coba lagi.';

  @override
  String get premiumNowOn => 'Premium aktif. Nikmati data tanpa batas.';

  @override
  String get premiumRestore => 'Pulihkan pembelian';

  @override
  String get premiumRestoreDone => 'Pembelian Anda dipulihkan di ponsel ini.';

  @override
  String get premiumRestoreNone =>
      'Google Play tidak punya pembelian untuk dipulihkan.';

  @override
  String get premiumRestoreFailed =>
      'Tidak dapat memulihkan pembelian Anda. Coba lagi nanti.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ditagih setiap $count hari. Diperpanjang otomatis sampai Anda membatalkan.',
      one:
          'Ditagih setiap hari. Diperpanjang otomatis sampai Anda membatalkan.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ditagih setiap $count minggu. Diperpanjang otomatis sampai Anda membatalkan.',
      one:
          'Ditagih setiap minggu. Diperpanjang otomatis sampai Anda membatalkan.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ditagih setiap $count bulan. Diperpanjang otomatis sampai Anda membatalkan.',
      one:
          'Ditagih setiap bulan. Diperpanjang otomatis sampai Anda membatalkan.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ditagih setiap $count tahun. Diperpanjang otomatis sampai Anda membatalkan.',
      one:
          'Ditagih setiap tahun. Diperpanjang otomatis sampai Anda membatalkan.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Diperpanjang otomatis sampai Anda membatalkan.';

  @override
  String get premiumPlayCancelNote =>
      'Anda bisa membatalkan kapan saja di Google Play. Premium tetap aktif sampai akhir masa yang sudah Anda bayar.';

  @override
  String get premiumManageSubscription => 'Kelola atau batalkan langganan';

  @override
  String get premiumCurrentPlan => 'Paket saat ini';

  @override
  String get premiumPlaySubscribed =>
      'Anda sudah punya langganan Google Play. Kelola atau batalkan di Google Play.';

  @override
  String get premiumEnterCode => 'Masukkan kode';

  @override
  String get premiumNeedsPlayVersion =>
      'Untuk membeli lewat Google Play, Anda memerlukan Fortiva versi Google Play.';

  @override
  String get premiumOff => 'Premium sedang tidak dijual.';

  @override
  String get premiumLoadFailed =>
      'Tidak dapat memuat Premium. Periksa koneksi Anda dan coba lagi.';

  @override
  String get premiumRetry => 'Coba lagi';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Bintang Telegram';
  }

  @override
  String get premiumPayCrypto => 'Bayar dengan kripto';

  @override
  String get premiumTelegramTitle => 'Bayar di Telegram';

  @override
  String get premiumTelegramBody =>
      'Bayar dengan Bintang Telegram di bot kami. Anda mendapat kunci, dan Premium langsung aktif di ponsel ini.';

  @override
  String get premiumTelegramButton => 'Beli di Telegram';

  @override
  String get premiumTelegramFailed =>
      'Tidak dapat membuka Telegram. Coba lagi.';

  @override
  String get checkoutTitle => 'Bayar dengan kripto';

  @override
  String get checkoutChooseNetwork =>
      'Pilih jaringan yang akan Anda pakai untuk mengirim';

  @override
  String get checkoutContinue => 'Lanjutkan';

  @override
  String get checkoutSendExactly => 'Kirim persis sebesar';

  @override
  String get checkoutNetwork => 'Jaringan';

  @override
  String get checkoutAddress => 'Ke alamat ini';

  @override
  String get checkoutMemo => 'Dengan memo ini';

  @override
  String get checkoutMemoWarning =>
      'Sertakan memo ini dalam transfer Anda, atau kami tidak bisa mencocokkan pembayaran dengan Anda.';

  @override
  String get checkoutExactWarning =>
      'Kirim jumlah yang tepat, hanya di jaringan ini. Jumlah atau jaringan yang berbeda mungkin tidak sampai ke kami.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Sisa waktu: $time';
  }

  @override
  String get checkoutWaiting =>
      'Menunggu pembayaran Anda. Halaman ini diperbarui sendiri.';

  @override
  String get checkoutPaidTitle => 'Pembayaran diterima';

  @override
  String get checkoutPaidKeyOnly =>
      'Kunci Anda sudah siap. Masukkan di ponsel yang akan mendapat Premium.';

  @override
  String get checkoutDone => 'Selesai';

  @override
  String get checkoutExpired =>
      'Pesanan ini sudah kedaluwarsa. Jika Anda sudah membayar, hubungi dukungan.';

  @override
  String get checkoutUnderpaid =>
      'Kami menerima kurang dari jumlah seharusnya. Hubungi dukungan dan berikan nomor pesanan ini:';

  @override
  String get checkoutCanceled => 'Pesanan ini dibatalkan.';

  @override
  String get checkoutStartAgain => 'Mulai lagi';

  @override
  String get checkoutUnavailable => 'Pembayaran kripto sedang tidak tersedia.';

  @override
  String get checkoutTooManyOpen =>
      'Anda punya terlalu banyak pesanan yang belum dibayar. Bayar salah satunya atau tunggu sampai kedaluwarsa.';

  @override
  String get checkoutUnknownPlan =>
      'Paket ini tidak dijual lagi. Kembali dan pilih paket lain.';

  @override
  String get checkoutFailed =>
      'Tidak dapat memulai pembayaran. Periksa koneksi Anda dan coba lagi.';

  @override
  String get redeemTitle => 'Masukkan kode';

  @override
  String get redeemSubtitle => 'Kunci Premium atau kode hadiah';

  @override
  String get redeemHint => 'Kode';

  @override
  String get redeemApply => 'Terapkan';

  @override
  String get redeemCancel => 'Batal';

  @override
  String get redeemInvalid =>
      'Ini tidak terlihat seperti kode. Periksa dan coba lagi.';

  @override
  String get redeemUnknown =>
      'Kami tidak mengenali kode ini. Periksa dan coba lagi.';

  @override
  String get redeemExpired => 'Kode ini sudah kedaluwarsa.';

  @override
  String get redeemRevoked => 'Kode ini tidak berlaku lagi.';

  @override
  String get redeemMovedTooOften =>
      'Kunci ini terlalu sering berpindah ponsel belakangan ini. Coba lagi nanti.';

  @override
  String get redeemExhausted => 'Kode ini sudah habis dipakai.';

  @override
  String get redeemAlreadyUsed => 'Ponsel ini sudah memakai kode ini.';

  @override
  String get redeemUnmetered =>
      'Ponsel ini sudah punya data tanpa batas, jadi tidak memerlukan kode ini.';

  @override
  String get redeemRateLimited =>
      'Terlalu banyak percobaan. Tunggu sebentar dan coba lagi.';

  @override
  String get redeemUnavailable => 'Ini sedang tidak tersedia. Coba lagi nanti.';

  @override
  String get redeemNetwork =>
      'Tidak dapat menjangkau server. Periksa koneksi Anda dan coba lagi.';

  @override
  String get redeemFailed => 'Kode itu tidak berfungsi. Periksa dan coba lagi.';

  @override
  String get redeemMoved => 'Premium dipindahkan ke ponsel ini.';

  @override
  String redeemPromo(String amount) {
    return 'Kode diterima. Data tambahan sebesar $amount ditambahkan.';
  }

  @override
  String get redeemPromoNoAmount => 'Kode diterima. Data tambahan ditambahkan.';

  @override
  String get tvScanTitle => 'Buka di ponsel Anda';

  @override
  String get tvScanBody => 'Arahkan kamera ponsel Anda ke kode ini.';

  @override
  String get refresh => 'Segarkan';

  @override
  String get premiumNotNow => 'Nanti saja';

  @override
  String get premiumLimitSheetTitle => 'Data hari ini sudah habis';

  @override
  String get premiumLimitWait => 'Tunggu sampai direset';

  @override
  String get premiumLimitInvite => 'Undang teman untuk data lebih banyak';

  @override
  String get premiumNoDailyLimit => 'Premium tidak punya batas harian.';

  @override
  String get premiumCalmTitle => 'Ingin tanpa batas harian?';

  @override
  String get premiumCalmBody =>
      'Premium memberi Anda data tanpa batas. Paket gratis Anda tetap seperti semula.';

  @override
  String get premiumNextStepTitle => 'Langkah berikutnya adalah Premium';

  @override
  String get premiumNextStepBody =>
      'Anda sudah punya data gratis terbanyak. Premium tidak punya batas harian.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Buka $place dengan Premium';
  }

  @override
  String get premiumLockedBody =>
      'Lokasi ini khusus Premium. Server gratis Anda tetap sama.';

  @override
  String get premiumHeadlineLimit => 'Tanpa batas harian';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Buka $place dengan Premium';
  }

  @override
  String get premiumFreeStays => 'Paket gratis tetap berfungsi tanpa Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium berakhir pada $date';
  }

  @override
  String get premiumRenewBody =>
      'Perpanjang untuk mempertahankan data tanpa batas. Perpanjangan menambah waktu ke tanggal berakhir Anda saat ini.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium berakhir pada $date. Paket gratis Anda kembali aktif.';
  }

  @override
  String get premiumRenew => 'Perpanjang';

  @override
  String get noticeChannelName => 'Pesan dari Fortiva';

  @override
  String get noticeChannelDescription => 'Berita dan pesan dari tim Fortiva';

  @override
  String get noticesSettingTitle => 'Notifikasi';

  @override
  String get noticesSettingOn =>
      'Aktif. Pesan dari tim Fortiva bisa sampai meski aplikasi ditutup.';

  @override
  String get noticesSettingOff =>
      'Nonaktif. Aktifkan untuk menerima pesan dari tim Fortiva meski aplikasi ditutup.';

  @override
  String get noticesOffCard =>
      'Aktifkan notifikasi untuk menerima pesan dari tim Fortiva meski aplikasi ditutup.';

  @override
  String get noticesTurnOn => 'Aktifkan';

  @override
  String get backgroundCard =>
      'Ponsel Anda mungkin menahan pesan dari tim Fortiva saat aplikasi ditutup. Izinkan Fortiva berjalan di latar belakang agar pesan tetap sampai.';

  @override
  String get backgroundHint =>
      'Di layar berikutnya, pilih Fortiva (jika tidak ada, tampilkan semua aplikasi). Lalu atur penggunaan baterai ke Tidak dibatasi, atau izinkan untuk mulai otomatis dan berjalan di latar belakang.';

  @override
  String get backgroundAllow => 'Izinkan';

  @override
  String get backgroundNotNow => 'Nanti saja';

  @override
  String get backgroundSettingTitle => 'Pesan saat aplikasi ditutup';

  @override
  String get backgroundSettingSubtitle =>
      'Izinkan Fortiva berjalan di latar belakang agar pesan tetap sampai saat aplikasi ditutup.';

  @override
  String get backgroundCardData =>
      'Penghemat Data di ponsel Anda mungkin menahan pesan dari tim Fortiva saat aplikasi ditutup.';

  @override
  String get backgroundHintData =>
      'Di layar berikutnya, aktifkan Data tanpa batas.';

  @override
  String get apnGuideTitle => 'Koneksi lebih stabil di SIM ini';

  @override
  String get apnGuideBody =>
      'Ponsel Anda tidak memakai IPv6 di SIM ini. Menyalakannya membantu Fortiva tetap terhubung.';

  @override
  String get apnGuideShowMe => 'Tunjukkan caranya';

  @override
  String get apnGuideNotNow => 'Nanti saja';

  @override
  String get apnGuideSheetTitle => 'Nyalakan IPv6 untuk SIM ini';

  @override
  String apnGuideStepOpen(String button) {
    return 'Ketuk \"$button\" (atau buka Pengaturan > Sambungan > Jaringan seluler > Nama Titik Akses).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Ketuk titik akses yang sedang dipakai ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Ketuk titik akses yang sedang dipakai.';

  @override
  String get apnGuideStepProtocol =>
      'Ketuk \"Protokol APN\" lalu pilih \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'Simpan (di Samsung: menu titik tiga, lalu \"Simpan\").';

  @override
  String get apnGuideStepRestart => 'Matikan data seluler, lalu nyalakan lagi.';

  @override
  String get apnGuideUndo =>
      'Jika data seluler berhenti berfungsi, kembalikan protokol APN ke IPv4.';

  @override
  String get apnGuideOpenSettings => 'Buka pengaturan APN';

  @override
  String get homeStallSearching =>
      'Koneksi berhenti berfungsi. Mencari jalur lain.';

  @override
  String get homeStalled => 'Terhubung, tetapi tidak ada data yang lewat';

  @override
  String get peerShareTitle => 'Bantu teman terhubung';

  @override
  String get peerShareSubtitle =>
      'Berikan apa yang dibutuhkan Fortiva ke ponsel teman';

  @override
  String get peerShareBody =>
      'Jika Fortiva teman Anda tidak bisa terhubung, ponselnya bisa mendapatkan apa yang dibutuhkan dari ponsel Anda. Ini bisa dilakukan tanpa internet.';

  @override
  String peerShareSteps(String action) {
    return 'Di ponselnya, buka Pengaturan di Fortiva dan ketuk \"$action\". Lalu tunjukkan kode-kode ini satu per satu, atau kirimkan ini kepadanya.';
  }

  @override
  String get peerShareLoading => 'Mengambil salinan terbaru';

  @override
  String get peerShareNothing =>
      'Ponsel ini belum punya yang baru untuk diberikan. Coba lagi nanti.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Kode $current dari $total';
  }

  @override
  String get peerSharePrevious => 'Sebelumnya';

  @override
  String get peerShareNext => 'Berikutnya';

  @override
  String get peerShareCopy => 'Salin';

  @override
  String get peerShareSend => 'Kirim';

  @override
  String get peerShareCopied => 'Disalin. Tempelkan di pesan untuk teman Anda.';

  @override
  String get peerReceiveTitle => 'Minta bantuan teman';

  @override
  String get peerReceiveSubtitle => 'Saat cara lain tidak bisa terhubung';

  @override
  String peerReceiveBody(String action) {
    return 'Minta teman yang Fortiva-nya bisa terhubung untuk membuka Pengaturan di Fortiva dan mengetuk \"$action\". Lalu ambil dari ponselnya dengan salah satu cara berikut.';
  }

  @override
  String get peerReceivePhotograph => 'Foto kode teman Anda';

  @override
  String get peerReceivePhotographNext => 'Foto kode berikutnya';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$have dari $total kode terbaca';
  }

  @override
  String get peerReceiveFile => 'Buka file kiriman teman';

  @override
  String get peerReceivePaste => 'Tempel kiriman teman';

  @override
  String get peerReceiveNoCode =>
      'Kode tidak ditemukan di foto itu. Dekatkan ponsel dan pastikan seluruh kode terlihat.';

  @override
  String get peerReceiveRefused =>
      'Fortiva tidak bisa memakainya. Minta teman Anda mengirimnya lagi.';

  @override
  String get peerReceiveNotNewer =>
      'Anda sudah punya ini, atau yang lebih baru. Coba hubungkan lagi, atau minta bantuan teman lain.';

  @override
  String get peerReceiveTaken =>
      'Selesai. Ketuk tombolnya untuk menghubungkan.';

  @override
  String get peerReceiveUnavailable =>
      'Ponsel ini tidak bisa melakukannya. Coba cara lain.';

  @override
  String get peerReceiveNothingToPaste =>
      'Belum ada yang disalin. Salin kiriman teman Anda, lalu ketuk di sini lagi.';

  @override
  String get peerOfferBody =>
      'Masih belum bisa terhubung? Teman yang Fortiva-nya berfungsi bisa membantu dari ponselnya.';

  @override
  String get peerReceiveAgain =>
      'Anda sudah punya kode ini. Minta teman Anda menunjukkan kode berikutnya.';

  @override
  String get peerReceivePasteNotOurs =>
      'Yang Anda salin bukan dari Fortiva. Salin seluruh pesan teman Anda, lalu coba lagi.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Kamera tidak mengembalikan fotonya. Ambil foto dengan aplikasi kamera, lalu ketuk \"$action\".';
  }

  @override
  String get peerReceiveFileHint =>
      'File dari aplikasi pesan mungkin perlu disimpan ke folder Download dulu.';

  @override
  String get homeTryingBackup =>
      'Tidak ada yang lain terhubung. Sekarang mencoba jaringan cadangan.';

  @override
  String get homeConnectedBackup => 'Terhubung lewat jaringan cadangan';

  @override
  String get backupNetwork => 'JARINGAN CADANGAN';

  @override
  String get backupNetworkTitle => 'Jaringan cadangan';

  @override
  String get backupNetworkCaption =>
      'Dipakai saat tidak ada yang lain terhubung. Bisa lebih lambat dari server kami.';

  @override
  String get backupNetworkPlace => 'Lokasi dipilih otomatis';

  @override
  String get speedTestStart => 'Mulai tes';

  @override
  String get speedTestAgain => 'Tes lagi';

  @override
  String get speedTestRunning => 'Sedang menguji';

  @override
  String get speedTestIdle => 'Lihat seberapa cepat koneksi Anda saat ini.';

  @override
  String get speedTestPhasePing => 'Memeriksa waktu respons';

  @override
  String get speedTestPhaseDownload => 'Mengukur kecepatan unduh';

  @override
  String get speedTestPhaseUpload => 'Mengukur kecepatan unggah';

  @override
  String get speedTestDone => 'Tes selesai';

  @override
  String get speedTestFailed =>
      'Tes tidak dapat diselesaikan. Periksa internet Anda lalu coba lagi.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'Alamat IP';

  @override
  String get ipCopied => 'Alamat disalin';

  @override
  String get ipLocation => 'Lokasi';

  @override
  String get ipProvider => 'Penyedia internet';

  @override
  String get ipOrganization => 'Organisasi';

  @override
  String get ipTimeZone => 'Zona waktu';

  @override
  String get ipCoordinates => 'Koordinat';

  @override
  String get ipCheckFailed => 'Alamat Anda tidak dapat diperiksa';

  @override
  String get historyAverage => 'Rata-rata';

  @override
  String get historyRecentDays => 'Hari-hari terakhir';

  @override
  String yesterdayAt(String time) {
    return 'Kemarin pukul $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date pukul $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds dtk';
  }

  @override
  String get stageOwn => 'Server Fortiva';

  @override
  String get stageCommunity => 'Server komunitas';

  @override
  String stageProgress(int n, int total) {
    return 'Tahap $n dari $total';
  }

  @override
  String get stageTryingOwn => 'Mencoba server Fortiva';

  @override
  String get stageTryingCommunity => 'Mencoba server komunitas';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Server Fortiva tidak terhubung di sini. Sekarang mencoba server komunitas.';

  @override
  String stageLastWorked(String server) {
    return 'Server terakhir yang berhasil: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '$count jalur dicoba, diblokir di sini';
  }

  @override
  String stageTriedFailed(int count) {
    return '$count jalur dicoba, tidak ada yang terhubung';
  }

  @override
  String get stageNotConnected => 'Tidak terhubung';

  @override
  String get stageConnected => 'Terhubung di sini';

  @override
  String get stageSkipped => 'Dilewati kali ini';

  @override
  String stageMoreToCheck(int count) {
    return '$count jalur lagi menunggu diperiksa';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Percobaan berikutnya dalam $time, mulai dari $stage';
  }

  @override
  String get searchSlowHint =>
      'Ini bisa memakan waktu satu atau dua menit. Ketuk tombol untuk menghentikan pencarian.';

  @override
  String get searchStopped => 'Pencarian dihentikan';

  @override
  String get homeConnectedCommunity => 'Terhubung lewat server komunitas';

  @override
  String get stageGettingServers => 'Mengambil server Anda';

  @override
  String stageNextTryStarting(String stage) {
    return 'Percobaan berikutnya dimulai sekarang dari $stage';
  }
}
