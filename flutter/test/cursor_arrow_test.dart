import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';

// The pointer shown until the remote cursor's own shape is known (or when the host cannot give it) is a plain arrow with its tip at the hot spot:
// it used to be a blue dot centred on the pointer.
void main() {
  test('the default cursor is an arrow, not a dot', () async {
    // the image is decoded in the background: wait until it is there
    for (var i = 0; i < 100 && preDefaultCursor.image == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(preDefaultCursor.image, isNotNull);
    expect(preDefaultCursor.id, kPreDefaultCursorId);
    // the point of the arrow is the hot spot (top left), not the middle of the picture
    expect(preDefaultCursor.hotx, lessThan(4));
    expect(preDefaultCursor.hoty, lessThan(4));

    final png = img.decodePng(base64Decode(_pngOfDefaultCursor()))!;
    expect(png.width, 32);
    expect(png.height, 32);
    final tip = png.getPixel(3, 8);
    expect(tip.a, 255, reason: 'inside the arrow');
    expect(tip.r, lessThan(80), reason: 'a dark arrow');
    final corner = png.getPixel(30, 2);
    expect(corner.a, 0, reason: 'the rest of the picture is clear');
  });
}

// the PNG the cursor was made from: the cache keeps the decoded copy, so read it back out of it
String _pngOfDefaultCursor() => base64Encode(img.encodePng(preDefaultCursor.cache!.image));
