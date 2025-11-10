enum PersonaSender { user, bot }

class PersonaMessage {
  final String id;
  final String text;
  final PersonaSender sender;
  final DateTime createdAt;

  PersonaMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.createdAt,
  });
}