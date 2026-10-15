String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
  return '$bytes B';
}

String? fileExtensionLower(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0 || idx == name.length - 1) return null;
  return name.substring(idx + 1).toLowerCase();
}

bool isImageFileName(String name) {
  const exts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'avif',
    'apng'
  };
  final ext = fileExtensionLower(name);
  return ext != null && exts.contains(ext);
}

bool isVideoFileName(String name) {
  final ext = fileExtensionLower(name);
  return ext == 'mp4' || ext == 'mov' || ext == 'm4v' || ext == 'webm';
}

String formatLocalDateTime(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
