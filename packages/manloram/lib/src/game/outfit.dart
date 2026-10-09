/// Traditional Lor dress a player can wear. Purely cosmetic: every outfit has
/// the same head and body hit shapes.
enum Outfit {
  kolah(
    'kolah',
    'Kolah namadi',
    'Felt hat, tunic, white sash and wide black trousers',
  ),
  chogha(
    'chogha',
    'Chogha',
    'The striped wool cloak of the Bakhtiari Lors, with a black felt hat',
  ),
  golvani(
    'golvani',
    'Golvani',
    'Flowered silk headscarf, coin vest and layered skirt',
  ),
  kapenak('kapenak', 'Kapenak', "The shepherd's stiff felt cloak");

  const Outfit(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static Outfit fromId(String? id) =>
      values.firstWhere((outfit) => outfit.id == id, orElse: () => kolah);
}
