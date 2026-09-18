import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('HexCoord', () {
    const origin = HexCoord(0, 0);

    test('uses the canonical axial neighbour vectors', () {
      expect(origin.neighbor(HexEdge.north), const HexCoord(0, -1));
      expect(origin.neighbor(HexEdge.northEast), const HexCoord(1, -1));
      expect(origin.neighbor(HexEdge.southEast), const HexCoord(1, 0));
      expect(origin.neighbor(HexEdge.south), const HexCoord(0, 1));
      expect(origin.neighbor(HexEdge.southWest), const HexCoord(-1, 1));
      expect(origin.neighbor(HexEdge.northWest), const HexCoord(-1, 0));
    });

    test('calculates axial distance and validates a direction', () {
      expect(origin.distanceTo(const HexCoord(2, -1)), 2);
      expect(origin.edgeToward(const HexCoord(1, -1)), HexEdge.northEast);
      expect(HexEdge.southWest.opposite, HexEdge.northEast);
      expect(() => HexEdge.fromIndex(6), throwsArgumentError);
      expect(
        () => origin.edgeToward(const HexCoord(2, 0)),
        throwsArgumentError,
      );
    });
  });
}
