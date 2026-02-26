class MyUser {
  final String uid;
  final String email;
  final String? name;
  final String? kycStatus;  // "pending", "approved", "rejected" veya null
  final String? idCardUrl;  // Kimlik resim linki
  final String? licenseUrl; // Ehliyet resim linki

  MyUser({
    required this.uid,
    required this.email,
    this.name,
    this.kycStatus,
    this.idCardUrl,
    this.licenseUrl,
  });

  // Veritabanından (Firebase) gelen veriyi uygulamaya tanıtır
  factory MyUser.fromMap(Map<String, dynamic> map, String id) {
    return MyUser(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'],
      kycStatus: map['kycStatus'],
      idCardUrl: map['idCardUrl'],
      licenseUrl: map['licenseUrl'],
    );
  }

  // Uygulamadaki veriyi veritabanına (Firebase) gönderilecek hale getirir
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'kycStatus': kycStatus,
      'idCardUrl': idCardUrl,
      'licenseUrl': licenseUrl,
    };
  }
}