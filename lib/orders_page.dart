import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'order_details_page.dart';

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
    // In initState, we assign the future directly, without setState.
    _orders = DatabaseHelper.instance.fetchOrderSummaries();
  }

  // This method is for clearing the filter and loading all orders.
  void _loadOrders() {
    setState(() {
      _selectedFilterDate = null;
      _orders = DatabaseHelper.instance.fetchOrderSummaries();
    });
  }

  // This method is for picking a date and filtering.
  Future<void> _filterByDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFilterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _selectedFilterDate = picked;
        _orders = DatabaseHelper.instance.fetchOrdersByDate(formattedDate);
      });
    }
  }

  // Delete an order, specified by orderId
  Future<void> _deleteOrder(int id) async {
    await DatabaseHelper.instance.deleteOrder(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order deleted successfully')),
    );
    // After deleting, just refresh the current view.
    _loadOrders();
  }

  // Navigate to the detail screen and handle the result.
  void _navigateToDetail(int orderId) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: orderId),
      ),
    );

    // If the detail screen popped with 'true', it means an update happened.
    if (result == true) {
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Orders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Filter by Date',
            onPressed: _filterByDate,
          ),
          if (_selectedFilterDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Filter',
              onPressed: _loadOrders,
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
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No orders found for this criteria.'));
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