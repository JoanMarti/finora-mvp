import 'package:finora/domain/institution_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => InstitutionCatalogue.neutralNames = false);

  test('neutral names keep ids, products and connection methods', () {
    final real = InstitutionCatalogue.all;
    InstitutionCatalogue.neutralNames = true;
    final neutral = InstitutionCatalogue.all;
    expect(neutral.map((i) => i.id), real.map((i) => i.id));
    for (var index = 0; index < real.length; index++) {
      expect(neutral[index].productTypes, real[index].productTypes);
      expect(neutral[index].connectionMethod, real[index].connectionMethod);
      expect(neutral[index].name, isNot(real[index].name));
    }
    expect(InstitutionCatalogue.nameOf('ubs'), 'Alpenrose Bank');
  });

  test('real names are the default', () {
    expect(InstitutionCatalogue.nameOf('ubs'), 'UBS');
  });
}
