enum UserRole { driver, shipper }

UserRole? roleFromString(String? v) {
  switch (v) {
    case 'driver':
      return UserRole.driver;
    case 'shipper':
      return UserRole.shipper;
    default:
      return null;
  }
}

String roleToString(UserRole role) => role == UserRole.driver ? 'driver' : 'shipper';

String roleLabel(UserRole? role) {
  if (role == UserRole.driver) return 'Şoför';
  if (role == UserRole.shipper) return 'Yük Sahibi';
  return 'Rol seçilmedi';
}
