import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ticket is read from the server answer, nothing else is', () {
    expect(relayTicketFrom({'ticket': 'abc.def', 'expires_in': 90}), 'abc.def');
    expect(relayTicketFrom(null), isNull);
    expect(relayTicketFrom({'expires_in': 90}), isNull);
    expect(relayTicketFrom({'ticket': 5}), isNull);
    expect(relayTicketFrom('abc'), isNull);
  });

  test('the local option name matches what the Rust core reads', () {
    // src/sd_ticket.rs: host id without "@server", ",..." and spaces
    expect(relayTicketOption('123456789'), 'sd_ticket:123456789');
    expect(relayTicketOption('123 456 789'), 'sd_ticket:123456789');
    expect(relayTicketOption('123456789@my.server.net'), 'sd_ticket:123456789');
    expect(relayTicketOption('123456789,key'), 'sd_ticket:123456789');
  });
}
