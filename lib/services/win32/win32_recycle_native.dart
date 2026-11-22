import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Native Win32 implementation using SHFileOperationW via Dart FFI.
/// Moves files to the Windows OS Recycle Bin in < 2ms without spawning PowerShell.
Future<bool> win32MoveToRecycleBin(List<String> files) async {
  if (!Platform.isWindows || files.isEmpty) return false;

  final existingPaths = files
      .map((f) => p.normalize(f))
      .where((f) => File(f).existsSync() || Directory(f).existsSync())
      .toList();

  if (existingPaths.isEmpty) return false;

  Pointer<Utf16>? pFrom;
  Pointer<SHFILEOPSTRUCT>? pOp;

  try {
    // Windows SHFileOperation requires double-null-terminated buffer: path1\0path2\0\0
    // When toNativeUtf16() is invoked, Dart appends the final terminating null character.
    // Joining paths with '\x00' and appending '\x00' produces the exact double-null termination.
    final rawBuffer = '${existingPaths.join('\x00')}\x00';
    pFrom = rawBuffer.toNativeUtf16();

    pOp = calloc<SHFILEOPSTRUCT>();
    pOp.ref.hwnd = 0;
    pOp.ref.wFunc = FO_DELETE;
    pOp.ref.pFrom = pFrom;
    pOp.ref.pTo = nullptr;
    pOp.ref.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT | FOF_NOERRORUI;
    pOp.ref.fAnyOperationsAborted = 0;
    pOp.ref.hNameMappings = nullptr;
    pOp.ref.lpszProgressTitle = nullptr;

    final result = SHFileOperation(pOp);
    return result == 0 && pOp.ref.fAnyOperationsAborted == 0;
  } catch (e) {
    debugPrint('Win32 FFI Error: SHFileOperation failed: $e');
    return false;
  } finally {
    if (pFrom != null) calloc.free(pFrom);
    if (pOp != null) calloc.free(pOp);
  }
}
