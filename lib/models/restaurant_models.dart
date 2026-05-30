class ProductOption {
  final String name;
  final double price; // 0 if included

  ProductOption({required this.name, this.price = 0.0});
}

class OptionGroup {
  final String title;
  final bool isMandatory;
  final bool isMultiSelect;
  final int minSelection;
  final int maxSelection;
  final List<ProductOption> options;

  OptionGroup({
    required this.title,
    this.isMandatory = false,
    this.isMultiSelect = false,
    this.minSelection = 0,
    this.maxSelection = 1,
    required this.options,
  });
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final List<OptionGroup> optionGroups;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.category = '',
    this.optionGroups = const [],
  });
}

class CartItem {
  final Product product;
  final List<ProductOption> selectedOptions;
  int quantity;

  CartItem({
    required this.product,
    required this.selectedOptions,
    this.quantity = 1,
  });

  double get totalPrice =>
      (product.price +
          selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) *
      quantity;
}






