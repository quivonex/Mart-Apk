import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/product_model.dart';
import '../screens/product_enquiry_screen.dart';
import '../utils/cart_helper.dart';

/// Product card.
/// Overflow-safe in both situations:
/// - bounded height (grid cell / fixed-height horizontal list): the image
///   flexes to fill whatever space is left.
/// - unbounded height (vertical list / Column): the image uses [imageHeight].
class ProductCard extends StatelessWidget {
  final Product product;
  final double imageHeight;

  /// Optional overrides. When null, the defaults are used:
  /// Enquiry -> CartHelper.showEnquiryDialog, Add -> CartHelper.addToCart.
  final VoidCallback? onEnquiry;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFranchiseTap;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.imageHeight = 112,
    this.onEnquiry,
    this.onAddToCart,
    this.onFranchiseTap,
    this.onTap,
  });

  bool get _hasDiscount =>
      product.discountValue.isNotEmpty && product.discountValue != '0';

  bool get _hasOldPrice => product.price != product.finalPrice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool bounded = constraints.hasBoundedHeight;

        final card = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DT.card,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(color: DT.border),
            boxShadow: DT.shadowXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (bounded)
                Expanded(child: _buildImage())
              else
                SizedBox(height: imageHeight, child: _buildImage()),
              const SizedBox(height: 8),
              _buildDetails(),
              const SizedBox(height: 10),
              _buildActions(context),
            ],
          ),
        );

        if (onTap == null) return card;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(DT.rLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: card),
        );
      },
    );
  }

  // ---------- Image with franchise badge ----------
  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DT.rMd),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: DT.slate100,
              borderRadius: BorderRadius.circular(DT.rMd),
            ),
            child: product.thumbnail.isNotEmpty
                ? Image.network(
              product.thumbnail,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
              progress == null ? child : _placeholder(),
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(),
            )
                : _placeholder(),
          ),
          if (product.isFranchiseAvailable)
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: onFranchiseTap,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: DT.blue50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: DT.blue200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 10, color: DT.blue700),
                      const SizedBox(width: 3),
                      Text(
                        'Franchise',
                        style: DT.text(
                          size: 9,
                          weight: FontWeight.w700,
                          color: DT.blue700,
                        ),
                      ),
                      if (onFranchiseTap != null) ...[
                        const SizedBox(width: 1),
                        const Icon(Icons.chevron_right_rounded,
                            size: 11, color: DT.blue700),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.image_outlined, color: DT.slate400, size: 34),
    );
  }

  // ---------- Text details ----------
  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.categoryName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DT.text(size: 10, weight: FontWeight.w500, color: DT.onyx600),
        ),
        const SizedBox(height: 2),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DT.text(
            size: 12,
            weight: FontWeight.w700,
            color: DT.onyx900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          product.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DT.text(size: 10, weight: FontWeight.w500, color: DT.slate500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '₹${product.finalPrice}',
              maxLines: 1,
              style: DT.text(
                size: 14,
                weight: FontWeight.w800,
                color: DT.onyx900,
              ),
            ),
            if (_hasOldPrice)
              Text(
                '₹${product.price}',
                style: DT.text(
                  size: 10,
                  weight: FontWeight.w500,
                  color: DT.slate400,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            if (_hasDiscount)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: DT.emerald50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${product.discountValue}% off',
                  style: DT.text(
                    size: 8.5,
                    weight: FontWeight.w700,
                    color: DT.emerald700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------- Buttons ----------
  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DT.slate100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: onEnquiry ??
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductEnquiryScreen(product: product),
                      ),
                    ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DT.onyx800,
                  side: const BorderSide(color: DT.slate300),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                ),
                child: Text(
                  'Enquiry',
                  style: DT.text(
                    size: 11,
                    weight: FontWeight.w700,
                    color: DT.onyx800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onAddToCart ??
                        () => CartHelper.addToCart(
                      context: context,
                      product: product,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.onyx900,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                ),
                child: Text(
                  'Add',
                  style: DT.text(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}