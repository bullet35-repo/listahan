import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

class OrderTypeField extends StatelessWidget {
  final TextEditingController controller;

  const OrderTypeField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final types = context.watch<OrderProvider>().orderTypes;
    final currentType = controller.text.trim();
    final dropdownTypes = {
      ...types,
      if (currentType.isNotEmpty) currentType,
    }.toList()..sort((a, b) => a.compareTo(b));

    return DropdownButtonFormField<String>(
      initialValue: dropdownTypes.contains(currentType) ? currentType : null,
      decoration: const InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category_rounded),
      ),
      items: dropdownTypes
          .map(
            (type) => DropdownMenuItem<String>(value: type, child: Text(type)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) controller.text = value;
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select type';
        }
        return null;
      },
    );
  }
}
