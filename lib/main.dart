import 'package:flutter/material.dart';
import 'database_helper.dart';
import'item.dart';
import 'package:intl/intl.dart';
import 'orders_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}


//--- Home Page ---
//Creates orders, displays all available food items
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}



class _MyHomePageState extends State<MyHomePage> {
  // --- STATE FOR BUDGETING & ORDERING ---

  final TextEditingController _targetCostController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<Item> _foodItems = [];
  bool _isLoading = true;
  final Map<int, int> _orderQuantities = {};

  // --- APP SETUP ---

  @override
  void initState() {
    super.initState();
    _fetchFoodItems();
  }

  Future<void> _fetchFoodItems() async {
    setState(() { _isLoading = true; });
    final items = await DatabaseHelper.instance.fetchItems();
    setState(() {
      _foodItems = items;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _targetCostController.dispose();
    super.dispose();
  }

  // --- BUDGET CALCULATION LOGIC ---

  double get _targetCost {
    // Safely parse the text from the controller into a double.
    return double.tryParse(_targetCostController.text) ?? 0.0;
  }

  double get _currentCost {
    double total = 0.0;
    _orderQuantities.forEach((foodId, quantity) {
      final food = _foodItems.firstWhere((item) => item.id == foodId);
      total += food.price * quantity;
    });
    return total;
  }

  double get _remainingBudget {
    return _targetCost - _currentCost;
  }

  // --- UI LOGIC ---

  void _increaseQuantity(Item food) {
    if (_targetCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a target cost first!')),
      );
      return;
    }
    if (_remainingBudget < food.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add item. It exceeds the remaining budget!')),
      );
      return;
    }
    setState(() {
      _orderQuantities[food.id!] = (_orderQuantities[food.id!] ?? 0) + 1;
    });
  }

  void _decreaseQuantity(int foodId) {
    setState(() {
      if ((_orderQuantities[foodId] ?? 0) > 1) {
        _orderQuantities[foodId] = _orderQuantities[foodId]! - 1;
      } else {
        _orderQuantities.remove(foodId);
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- DATABASE METHODS ---

  Future<void> _completeOrder() async {
    if (_targetCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid target cost.')));
      return;
    }
    if (_orderQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your order is empty!')));
      return;
    }

    List<Item> orderItems = [];
    _orderQuantities.forEach((foodId, quantity) {
      final item = _foodItems.firstWhere((item) => item.id == foodId);
      orderItems.add(item);
    });

    final date = DateFormat("yyyy-MM-dd").format(_selectedDate);

    try {
      final newOrderId = await DatabaseHelper.instance.insertOrder(
        orderItems,
        _orderQuantities,
        date,
        _currentCost,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meal Plan Saved'),
          content: Text(
              'Your meal plan (ID: $newOrderId) for ${DateFormat('yyyy-MM-dd').format(_selectedDate)} has been saved with a target cost of \$${_currentCost.toStringAsFixed(2)}.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _orderQuantities.clear();
                  _targetCostController.clear();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing order: $e')));
    }
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Meals'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'View Past Orders',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const OrdersScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _targetCostController,
                  decoration: const InputDecoration(
                    labelText: 'Target Cost per Day',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => setState(() {}), // Rebuild to update budget
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Date:', style: TextStyle(fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      onPressed: () => _selectDate(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Budget:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _remainingBudget < 0 ? Colors.red : Colors.green[800]),
                    ),
                    Text(
                      '\$${_remainingBudget.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _remainingBudget < 0 ? Colors.red : Colors.green[800]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- SAVE BUTTON ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _completeOrder,
                icon: const Icon(Icons.save),
                label: const Text('Save Meal Plan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          const Divider(),

          // --- FOOD LIST ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _foodItems.length,
              itemBuilder: (context, index) {
                final food = _foodItems[index];
                final quantity = _orderQuantities[food.id!] ?? 0;
                // Determine if adding another of this item is possible
                final canAddItem = _remainingBudget >= food.price;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(food.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('\$${food.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        // Quantity Controls
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: quantity > 0 ? () => _decreaseQuantity(food.id!) : null,
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: canAddItem ? Colors.green : Colors.grey),
                              onPressed: canAddItem ? () => _increaseQuantity(food) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}