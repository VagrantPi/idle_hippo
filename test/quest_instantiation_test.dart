import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/pet_ticket_quest_service.dart';

void main() {
  test('PetTicketQuestService can be instantiated', () {
    final service = PetTicketQuestService();
    expect(service, isA<PetTicketQuestService>());
  });
}
