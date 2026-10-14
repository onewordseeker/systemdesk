import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as w32;

/// The Windows Security password dialog (current account name pre-filled), checked with LogonUser. Plain FFI so it
/// runs on its own thread (Isolate.run) and can be tested without the rest of the app.
/// Returns one of the kWinAuth* codes.
const kWinAuthOk = 0, kWinAuthCancelled = 1, kWinAuthWrong = 2, kWinAuthError = 3;

final class _CredUiInfo extends Struct {
  @Uint32()
  external int cbSize;
  @IntPtr()
  external int hwndParent;
  external Pointer<Utf16> pszMessageText;
  external Pointer<Utf16> pszCaptionText;
  @IntPtr()
  external int hbmBanner;
}

const _credUiWinGeneric = 0x1;
const _errorCancelled = 1223;
const _errorLogonFailure = 1326;
const _logonInteractive = 2, _logonNetwork = 3;

final _credui = DynamicLibrary.open('credui.dll');
final _advapi = DynamicLibrary.open('advapi32.dll');
final _ole = DynamicLibrary.open('ole32.dll');

final _prompt = _credui.lookupFunction<
    Uint32 Function(Pointer<_CredUiInfo>, Uint32, Pointer<Uint32>, Pointer<Void>, Uint32, Pointer<Pointer<Void>>,
        Pointer<Uint32>, Pointer<Int32>, Uint32),
    int Function(Pointer<_CredUiInfo>, int, Pointer<Uint32>, Pointer<Void>, int, Pointer<Pointer<Void>>,
        Pointer<Uint32>, Pointer<Int32>, int)>('CredUIPromptForWindowsCredentialsW');
final _pack = _credui.lookupFunction<
    Int32 Function(Uint32, Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint8>, Pointer<Uint32>),
    int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint8>, Pointer<Uint32>)>('CredPackAuthenticationBufferW');
final _unpack = _credui.lookupFunction<
    Int32 Function(Uint32, Pointer<Void>, Uint32, Pointer<Utf16>, Pointer<Uint32>, Pointer<Utf16>, Pointer<Uint32>,
        Pointer<Utf16>, Pointer<Uint32>),
    int Function(int, Pointer<Void>, int, Pointer<Utf16>, Pointer<Uint32>, Pointer<Utf16>, Pointer<Uint32>,
        Pointer<Utf16>, Pointer<Uint32>)>('CredUnPackAuthenticationBufferW');
final _logon = _advapi.lookupFunction<
    Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Uint32, Uint32, Pointer<IntPtr>),
    int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, int, int, Pointer<IntPtr>)>('LogonUserW');
final _freeCom = _ole.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('CoTaskMemFree');

void _wipe(Pointer<Uint16> p, int chars) {
  for (var i = 0; i < chars; i++) {
    p[i] = 0;
  }
}

/// A packed credential (what the dialog returns) -> does Windows accept this user + password?
/// ok = true when LogonUser accepts it; err = Windows error otherwise, or -1 when the buffer could not be read.
({bool ok, int err}) _checkBuffer(Pointer<Void> buf, int size) {
  final nUser = calloc<Uint32>();
  final nDomain = calloc<Uint32>();
  final nPass = calloc<Uint32>();
  Pointer<Utf16> user = nullptr, domain = nullptr, pass = nullptr;
  var passChars = 0;
  try {
    _unpack(0, buf, size, nullptr, nUser, nullptr, nDomain, nullptr, nPass);
    if (nUser.value == 0 || nPass.value == 0) return (ok: false, err: -1);
    user = calloc<Uint16>(nUser.value).cast<Utf16>();
    domain = calloc<Uint16>(nDomain.value + 1).cast<Utf16>();
    pass = calloc<Uint16>(nPass.value).cast<Utf16>();
    passChars = nPass.value;
    if (_unpack(0, buf, size, user, nUser, domain, nDomain, pass, nPass) == 0) return (ok: false, err: -1);

    var u = user.toDartString();
    var d = nDomain.value > 1 ? domain.toDartString() : '';
    if (d.isEmpty && u.contains('\\')) {
      d = u.substring(0, u.indexOf('\\'));
      u = u.substring(u.indexOf('\\') + 1);
    }
    final userPtr = u.toNativeUtf16();
    final domainPtr = (d.isEmpty || u.contains('@')) ? nullptr : d.toNativeUtf16();
    final token = calloc<IntPtr>();
    try {
      var err = 0;
      for (final type in [_logonInteractive, _logonNetwork]) {
        if (_logon(userPtr, domainPtr, pass, type, 0, token) != 0) {
          w32.CloseHandle(token.value);
          return (ok: true, err: 0);
        }
        err = w32.GetLastError();
        if (err == _errorLogonFailure) break; // the password itself is wrong, no point trying the other type
      }
      return (ok: false, err: err == 0 ? _errorLogonFailure : err);
    } finally {
      calloc.free(token);
      calloc.free(userPtr);
      if (domainPtr != nullptr) calloc.free(domainPtr);
    }
  } finally {
    if (pass != nullptr) {
      _wipe(pass.cast<Uint16>(), passChars);
      calloc.free(pass);
    }
    if (user != nullptr) calloc.free(user);
    if (domain != nullptr) calloc.free(domain);
    calloc.free(nUser);
    calloc.free(nDomain);
    calloc.free(nPass);
  }
}

/// Packs "DOMAIN\user" (+ optional password) the way the dialog expects/returns it. Caller frees with calloc.free.
({Pointer<Uint8> buf, int size})? _packCredential(String account, String password) {
  final a = account.toNativeUtf16();
  final p = password.toNativeUtf16();
  final size = calloc<Uint32>();
  try {
    _pack(0, a, p, nullptr, size);
    if (size.value == 0) return null;
    final buf = calloc<Uint8>(size.value);
    if (_pack(0, a, p, buf, size) == 0) {
      calloc.free(buf);
      return null;
    }
    return (buf: buf, size: size.value);
  } finally {
    _wipe(p.cast<Uint16>(), password.length);
    calloc.free(a);
    calloc.free(p);
    calloc.free(size);
  }
}

/// For tests: check a user + password through the same code path the dialog result takes. 0 ok, 2 wrong, 3 error.
int windowsCheckCredential(String account, String password) {
  final packed = _packCredential(account, password);
  if (packed == null) return kWinAuthError;
  try {
    final r = _checkBuffer(packed.buf.cast<Void>(), packed.size);
    if (r.ok) return kWinAuthOk;
    return r.err == -1 ? kWinAuthError : kWinAuthWrong;
  } finally {
    calloc.free(packed.buf);
  }
}

int windowsPasswordPrompt(String reason) {
  final info = calloc<_CredUiInfo>();
  final caption = 'SystemDesk'.toNativeUtf16();
  final message = reason.toNativeUtf16();
  info.ref
    ..cbSize = sizeOf<_CredUiInfo>()
    ..hwndParent = w32.GetForegroundWindow()
    ..pszMessageText = message
    ..pszCaptionText = caption
    ..hbmBanner = 0;

  // pre-fill the signed-in Windows account so only the password has to be typed
  final account = '${Platform.environment['USERDOMAIN'] ?? ''}\\${Platform.environment['USERNAME'] ?? ''}';
  final prefill = account.length > 1 ? _packCredential(account, '') : null;

  final authPackage = calloc<Uint32>();
  final outBuf = calloc<Pointer<Void>>();
  final outSize = calloc<Uint32>();
  final save = calloc<Int32>();

  var result = kWinAuthError;
  try {
    var authError = 0;
    for (var attempt = 0; attempt < 3; attempt++) {
      outBuf.value = nullptr;
      final rc = _prompt(info, authError, authPackage, prefill?.buf.cast<Void>() ?? nullptr, prefill?.size ?? 0,
          outBuf, outSize, save, _credUiWinGeneric);
      if (rc == _errorCancelled) {
        result = kWinAuthCancelled;
        break;
      }
      if (rc != 0 || outBuf.value == nullptr) {
        result = kWinAuthError;
        break;
      }
      try {
        final r = _checkBuffer(outBuf.value, outSize.value);
        if (r.ok) {
          result = kWinAuthOk;
          break;
        }
        if (r.err == -1) {
          result = kWinAuthError;
          break;
        }
        result = kWinAuthWrong;
        authError = r.err;
      } finally {
        final bytes = outBuf.value.cast<Uint8>();
        for (var i = 0; i < outSize.value; i++) {
          bytes[i] = 0;
        }
        _freeCom(outBuf.value);
        outBuf.value = nullptr;
      }
    }
  } finally {
    if (prefill != null) calloc.free(prefill.buf);
    calloc.free(authPackage);
    calloc.free(outBuf);
    calloc.free(outSize);
    calloc.free(save);
    calloc.free(message);
    calloc.free(caption);
    calloc.free(info);
  }
  return result;
}
