import 'package:flutter_test/flutter_test.dart';
import 'package:kasat_mobile/features/resources/emergency_contacts.dart';
import 'package:kasat_mobile/models/country.dart';

void main() {
  group('country table', () {
    test('Ethiopia and the United States are the launched countries', () {
      expect(activeCountries.map((c) => c.code).toSet(), {'ET', 'US'});
    });

    test('the picker lists every country and can be searched', () {
      expect(kCountries.length, greaterThan(180));
      expect(countryByCode('US')?.name, 'United States');
      expect(countryByCode('US')?.flag, isNotEmpty);
      expect(countriesMatching('ethi').map((c) => c.code), contains('ET'));
      expect(countriesMatching('united states').map((c) => c.code), contains('US'));
      expect(countriesMatching('zzzzz'), isEmpty);
    });

    test('every launched country has contacts', () {
      for (final country in activeCountries) {
        expect(
          contactsForCountry(country.code),
          isNotEmpty,
          reason: '${country.name} is active but has no contacts',
        );
      }
    });

    test('resolves a country by code', () {
      expect(countryByCode('ET')?.name, 'Ethiopia');
      expect(countryByCode('ZZ'), isNull);
      expect(countryByCode(null), isNull);
    });
  });

  group('contactsForCountry', () {
    test('covers the three kinds of help the brief calls for', () {
      final kinds = contactsForCountry('ET').map((c) => c.kind).toSet();

      expect(kinds, contains(ContactKind.federalPolice));
      expect(kinds, contains(ContactKind.womensAffairs));
      expect(kinds, contains(ContactKind.ngo));
    });

    test('returns empty for an unlaunched country instead of another\'s numbers',
        () {
      // Showing a Kenyan number to someone in Somalia is a failure, not a
      // graceful fallback.
      expect(contactsForCountry('KE'), isEmpty);
      expect(contactsForCountry('SO'), isEmpty);
      expect(contactsForCountry('ZZ'), isEmpty);
      expect(contactsForCountry(null), isEmpty);
    });

    test('every shipped number is still an unverified placeholder', () {
      // Flip these to verified per entry as real numbers are confirmed; this
      // test is what stops a placeholder reaching a survivor as dialable.
      for (final list in emergencyContactsByCountry.values) {
        for (final contact in list) {
          expect(
            contact.verified,
            isFalse,
            reason: '${contact.name} is marked verified — is the number real?',
          );
        }
      }
    });

    test('strips formatting to a dialable string', () {
      const contact = EmergencyContact(
        name: 'x',
        number: '+251-000-000-001',
        kind: ContactKind.federalPolice,
        hours: 'x',
        blurb: 'x',
      );

      expect(contact.dialable, '+251000000001');
    });
  });

  group('crisisLinesForCountry', () {
    test('offers at most two lines, police and women\'s affairs first', () {
      final lines = crisisLinesForCountry('ET');

      expect(lines.length, lessThanOrEqualTo(2));
      expect(lines.first.kind, ContactKind.federalPolice);
      expect(lines.every((c) => c.isCrisisLine), isTrue);
    });

    test('is empty for an unlaunched country', () {
      expect(crisisLinesForCountry('KE'), isEmpty);
    });
  });

  group('groupedContactsForCountry', () {
    test('orders groups by urgency and omits empty ones', () {
      final grouped = groupedContactsForCountry('ET');

      expect(grouped.keys.first, ContactKind.federalPolice);
      expect(grouped.values.every((list) => list.isNotEmpty), isTrue);
    });
  });
}
