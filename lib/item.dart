class Item {
  final int? id;
  final String name;
  final double price;

  Item({this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'price': price,
  };

  static Item fromJson(Map<String, dynamic> json) => Item(
      id: (json['id'] as num).toInt(),
      name: json['name'],
      price: (json['price'] as num).toDouble(),
  );

}