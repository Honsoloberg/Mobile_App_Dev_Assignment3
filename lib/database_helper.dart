import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'item.dart';

class DatabaseHelper {
  static final _dbName = "food_app.db";
  static final _dbVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Completer<Database>? _dbOpenCompleter;


  Future<Database> get database async {
    if (_dbOpenCompleter == null) {
      _dbOpenCompleter = Completer();
      _initDB(_dbName).then((db) {
        _dbOpenCompleter!.complete(db);
      }).catchError((error) {
        _dbOpenCompleter!.completeError(error);
      });
    }

    return _dbOpenCompleter!.future;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onConfigure: (db) async {await db.execute('PRAGMA foreign_keys = ON');},
    );
  }

  Future _createDB(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
      CREATE TABLE foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL
        )
      ''');

      await txn.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        target_cost REAL NOT NULL
      )
      ''');

      await txn.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY(item_id) REFERENCES foods(id)
      )
      ''');

      final batch = txn.batch();

      batch.insert('foods', {'name': 'Classic Burger', 'price': 9.99});
      batch.insert('foods', {'name': 'Margherita Pizza', 'price': 12.50});
      batch.insert('foods', {'name': 'Chicken Caesar Salad', 'price': 8.75});
      batch.insert('foods', {'name': 'Spaghetti Carbonara', 'price': 11.25});
      batch.insert('foods', {'name': 'Fish and Chips', 'price': 13.00});
      batch.insert('foods', {'name': 'Veggie Wrap', 'price': 7.99});
      batch.insert('foods', {'name': 'Steak Frites', 'price': 18.50});
      batch.insert('foods', {'name': 'Mushroom Risotto', 'price': 14.00});
      batch.insert('foods', {'name': 'Tomato Soup', 'price': 5.50});
      batch.insert('foods', {'name': 'Club Sandwich', 'price': 10.25});
      batch.insert('foods', {'name': 'Sushi Platter', 'price': 22.00});
      batch.insert('foods', {'name': 'Pad Thai', 'price': 13.75});
      batch.insert('foods', {'name': 'Tuna Melt', 'price': 8.50});
      batch.insert('foods', {'name': 'BBQ Ribs', 'price': 19.99});
      batch.insert('foods', {'name': 'Falafel Plate', 'price': 9.00});
      batch.insert('foods', {'name': 'Beef Tacos', 'price': 10.00});
      batch.insert('foods', {'name': 'French Onion Soup', 'price': 6.75});
      batch.insert('foods', {'name': 'Chicken Wings (10pcs)', 'price': 11.50});
      batch.insert('foods', {'name': 'Pepperoni Calzone', 'price': 12.75});
      batch.insert('foods', {'name': 'Shrimp Scampi', 'price': 16.50});

      await batch.commit(noResult: true);
    });
  }

  Future<int> insertItem(Item item) async{
    final db = await instance.database;
    return await db.insert('foods', item.toJson());
  }

  //Get all available items
  Future<List<Item>> fetchItems() async{
    final db = await instance.database;
    final result = await db.query('foods');

    //convert to list of Item objects
    return result.map((json) => Item.fromJson(json)).toList();
  }

  Future<int> insertOrder(List<Item> orderItems, Map<int, int> quantities, String date, double targetCost) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      //Insert main order into order table
      int orderID = await txn.insert('orders', {
        'date': date,
        'target_cost': targetCost,
      });

      //Insert all items in order into order_items
      final batch = txn.batch();
      for (var itemId in quantities.keys) {
        final quantity = quantities[itemId];
        if (quantity != null && quantity > 0) {
          batch.insert('order_items', {
            'order_id': orderID,
            'item_id': itemId,
            'quantity': quantity,
          });
        }
      }

      await batch.commit(noResult: true);

      //Return the ID of the main order.
      return orderID;
    });
  }


  Future<List<Map<String, dynamic>>> fetchOrderSummaries() async {
    final db = await instance.database;
    return await db.query('orders', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> fetchOrderDetails(int orderId) async {
    final db = await instance.database;
    final result = db.rawQuery(''' 
      SELECT oi.item_id, oi.quantity, f.name, f.price
      FROM order_items oi
      INNER JOIN foods f ON oi.item_id = f.id
      WHERE oi.order_id = ?
    ''', [orderId]);
    return result;
  }

  Future<int> deleteOrder(int orderId) async {
    final db = await instance.database;
    return await db.delete("orders", where: 'id = ?', whereArgs: [orderId]);
  }

  Future<void> updateOrder(int orderId, Map<int, int> newQuantities, double newTotal, [String? date = null]) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      //Delete the old items for this order.
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);

      //Create a batch to insert the new items.
      final batch = txn.batch();
      newQuantities.forEach((itemId, quantity) {
        if (quantity > 0) {
          batch.insert('order_items', {
            'order_id': orderId,
            'item_id': itemId,
            'quantity': quantity,
          });
        }
      });
      await batch.commit(noResult: true);

      //Update main order
      if(date == null){
        await txn.update(
            'orders',
            {'target_cost': newTotal},
            where: 'id = ?',
            whereArgs: [orderId]
        );
      }else{
        await txn.update(
            'orders',
            { 'target_cost': newTotal, 'date': date },
            where: 'id = ?',
            whereArgs: [orderId]
        );
      }

    });
  }

  Future<List<Map<String, dynamic>>> fetchOrdersByDate(String date) async {
    final db = await instance.database;
    return await db.query(
      'orders',
      where: 'date LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'date DESC',
    );
  }
}