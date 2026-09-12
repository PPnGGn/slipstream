import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';

void main() {
  group('GeoCatalog', () {
    test('parses site/ip token lists and lower-cases them', () {
      final c = GeoCatalog.fromJson({
        'site': ['geosite:Category-RU', 'geosite:vk'],
        'ip': ['geoip:RU'],
      });

      expect(c.site, {'geosite:category-ru', 'geosite:vk'});
      expect(c.ip, {'geoip:ru'});
      expect(c.isEmpty, isFalse);
    });

    test('has() is case- and whitespace-insensitive across both sets', () {
      final c = GeoCatalog.fromJson({
        'site': ['geosite:category-ru'],
        'ip': ['geoip:private'],
      });

      expect(c.has('geosite:category-ru'), isTrue);
      expect(c.has('  GEOSITE:CATEGORY-RU '), isTrue);
      expect(c.has('geoip:private'), isTrue);
      expect(c.has('geosite:youtube'), isFalse);
      expect(c.has('geoip:ru'), isFalse);
    });

    test('empty catalog matches nothing', () {
      const c = GeoCatalog.empty();
      expect(c.isEmpty, isTrue);
      expect(c.has('geosite:category-ru'), isFalse);
    });

    test('round-trips through json with sorted, deduped tokens', () {
      final json = GeoCatalog.fromJson({
        'site': ['geosite:vk', 'geosite:apple', 'geosite:vk'],
        'ip': ['geoip:ru'],
      }).toJson();

      expect(json['site'], ['geosite:apple', 'geosite:vk']);
      expect(json['ip'], ['geoip:ru']);
    });

    test('tolerates missing keys', () {
      final c = GeoCatalog.fromJson({'site': ['geosite:vk']});
      expect(c.ip, isEmpty);
      expect(c.has('geosite:vk'), isTrue);
    });
  });
}
