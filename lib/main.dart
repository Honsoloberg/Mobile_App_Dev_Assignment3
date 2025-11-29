import 'package:flutter/material.dart';
import 'database_helper.dart';
import'item.dart';
import 'package:intl/intl.dart';

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
        _targetCost,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meal Plan Saved'),
          content: Text(
              'Your meal plan (ID: $newOrderId) for ${DateFormat('yyyy-MM-dd').format(_selectedDate)} has been saved with a target cost of \$${_targetCost.toStringAsFixed(2)}.'),
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
                            // **CRITICAL UI CHANGE**: Disable button if budget is insufficient
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












//--- Orders Screen ---
//View all orders
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}



class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _orders;
  DateTime? _selectedFilterDate;


  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  //Get all orders from database
  void _loadOrders() {
    final temp = DatabaseHelper.instance.fetchOrderSummaries();
    setState(() {
      _orders = temp;
    });
  }

  Future<void> _selectFilterDate() async {
    final DateTime? picked = await _selectDate(context);

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        // Fetch orders specifically for the picked date
        _orders = DatabaseHelper.instance.fetchOrdersByDate(formattedDate);
        _selectedFilterDate = picked; // Store the date for UI feedback
      });
    }
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Order Date'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: CalendarDatePicker(
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2101),
              onDateChanged: (DateTime date) {
                selectedDate = date;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(selectedDate);
              },
            ),
          ],
        );
      },
    );
  }

  //Delete an order, specified by orderId
  Future<void> _deleteOrder(int id) async {
    await DatabaseHelper.instance.deleteOrder(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order deleted successfully')),
    );

    //Reload the list of orders after deletion.
    setState(() {
      _loadOrders();
    });
  }

  void _navigateToDetail(int orderId) async {
    //Navigate to the detail screen and wait for a result.
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: orderId),
      ),
    );

    //If the detail screen returns 'true',order was updated.
    if (result == true) {
      setState(() {
        _loadOrders(); //Update orders list.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Orders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          //The search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Filter by Date',
            onPressed: _selectFilterDate,
          ),
          if (_selectedFilterDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Filter',
              onPressed: () {
                setState(() {
                  _selectedFilterDate = null;
                  _loadOrders();
                });
              }
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedFilterDate != null)
            Container(
              width: double.infinity,
              color: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'Showing orders for: ${DateFormat('yyyy-MM-dd').format(_selectedFilterDate!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _orders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No orders found for this date.'));
                }
                final orders = snapshot.data!;
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final orderId = order['id'];
                    final orderDate = DateTime.parse(order['date']);
                    final totalCost = order['target_cost'] as double;
                    final date = DateFormat('yyyy-MM-dd').format(orderDate.toLocal());

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('Order #$orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Date: $date\nTotal: \$${totalCost.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteOrder(orderId),
                        ),
                        onTap: () => _navigateToDetail(orderId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}












//--- Order Detail Screen ---
//Updates individual orders
class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}



class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<int, int> _orderQuantities = {};
  List<Item> _orderItems = [];
  bool _isLoading = true;

  //--- Load Order ---

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  //Fetch all food items and other order details.
  Future<void> _loadOrderDetails() async {
    final allFoods = await DatabaseHelper.instance.fetchItems();
    final orderDetails = await DatabaseHelper.instance.fetchOrderDetails(widget.orderId);

    final quantities = {
      for (var item in orderDetails) (item['item_id'] as int): (item['quantity'] as int)
    };

    List<Item> itemsInThisOrder = [];
    for (var food in allFoods) {
      if (quantities.containsKey(food.id)) {
        itemsInThisOrder.add(food);
      }
    }

    setState(() {
      _orderItems = itemsInThisOrder;
      _orderQuantities = quantities;
      _isLoading = false;
    });
  }

  // --- UI Logic ---

  void _increaseQuantity(int foodId) {
    setState(() {
      _orderQuantities[foodId] = (_orderQuantities[foodId] ?? 0) + 1;
    });
  }

  void _decreaseQuantity(int foodId) {
    setState(() {
      final currentQuantity = _orderQuantities[foodId] ?? 0;
      //If quantity becomes zero or less, remove it from the list and the map.
      if (currentQuantity <= 1) {
        _orderQuantities.remove(foodId);
        _orderItems.removeWhere((item) => item.id == foodId);
      } else {
        _orderQuantities[foodId] = currentQuantity - 1;
      }
    });
  }

  double get _totalPrice {
    double total = 0;
    for (var item in _orderItems) {
      final quantity = _orderQuantities[item.id] ?? 0;
      total += item.price * quantity;
    }
    return total;
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Order Date'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: CalendarDatePicker(
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2101),
              onDateChanged: (DateTime date) {
                selectedDate = date;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(selectedDate);
              },
            ),
          ],
        );
      },
    );
  }


  // --- Functionality ---

  Future<void> _changeDate() async {
    final selectedDate = await _selectDate(context);

    if (selectedDate == null) return;
    final date = DateFormat("yyyy-MM-dd").format(selectedDate);

    await DatabaseHelper.instance.updateOrder(widget.orderId, _orderQuantities, _totalPrice, date);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order date updated successfully!')),
    );
  }


  Future<void> _updateOrderItems() async {
    //If all items have been removed, delete the order.
    if (_orderQuantities.isEmpty) {
      await DatabaseHelper.instance.deleteOrder(widget.orderId);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order deleted as it is now empty.')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    await DatabaseHelper.instance.updateOrder(widget.orderId, _orderQuantities, _totalPrice);

    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order updated successfully!')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Order #${widget.orderId}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_sharp),
            tooltip: 'Change Date',
            onPressed: _changeDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          //"Update Order" Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: ElevatedButton.icon(
              onPressed: _updateOrderItems,
              icon: const Icon(Icons.save),
              label: Text('Update Order (\$${_totalPrice.toStringAsFixed(2)})'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          //List of food items IN THIS ORDER
          Expanded(
            child: ListView.builder(
              itemCount: _orderItems.length,
              itemBuilder: (context, index) {
                final food = _orderItems[index];
                final quantity = _orderQuantities[food.id] ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        // Quantity controls
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _decreaseQuantity(food.id!),
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => _increaseQuantity(food.id!),
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