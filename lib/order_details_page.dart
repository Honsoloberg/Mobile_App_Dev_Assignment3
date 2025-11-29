import 'package:flutter/material.dart';
import 'database_helper.dart';
import'item.dart';
import 'package:intl/intl.dart';

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

    Navigator.of(context).pop(true);
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