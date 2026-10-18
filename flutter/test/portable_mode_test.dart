import 'package:flutter_hbb/utils/portable_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dir = r'C:\Program Files\SystemDesk';

  test('the copy in the install folder is the installed app (no Install button)', () {
    expect(runsFromInstallFolder(r'C:\Program Files\SystemDesk\SystemDesk.exe', dir), isTrue);
    expect(runsFromInstallFolder(r'c:\program files\systemdesk\SystemDesk.exe', dir), isTrue);
    expect(runsFromInstallFolder('C:/Program Files/SystemDesk/SystemDesk.exe', dir), isTrue);
    expect(runsFromInstallFolder(r'C:\Program Files\SystemDesk\data\x.exe', r'C:\Program Files\SystemDesk\'), isTrue);
  });

  test('Downloads, Desktop and temp folders are portable runs (Install button)', () {
    expect(runsFromInstallFolder(r'C:\Users\Ann\Downloads\SystemDesk.exe', dir), isFalse);
    expect(runsFromInstallFolder(r'C:\Users\Ann\Desktop\SystemDesk.exe', dir), isFalse);
    expect(runsFromInstallFolder(r'C:\Users\Ann\AppData\Local\Temp\SystemDesk\SystemDesk.exe', dir), isFalse);
    expect(runsFromInstallFolder(r'D:\Tools\SystemDesk.exe', dir), isFalse);
  });

  test('a look-alike folder is not the install folder', () {
    expect(runsFromInstallFolder(r'C:\Program Files\SystemDesk-old\SystemDesk.exe', dir), isFalse);
    expect(runsFromInstallFolder(r'C:\Program Files\SystemDeskPortable.exe', dir), isFalse);
    expect(runsFromInstallFolder(r'C:\Users\Ann\Downloads\Program Files\SystemDesk\SystemDesk.exe', dir), isFalse);
  });

  test('an unknown install folder is never "installed"', () {
    expect(runsFromInstallFolder(r'C:\Program Files\SystemDesk\SystemDesk.exe', ''), isFalse);
  });
}
