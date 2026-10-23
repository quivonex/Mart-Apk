from decimal import Decimal

from django.db.models import Q
from django.utils import timezone

from product.models import Product
from order.models import Order
from cart.models import CartItem

from olx.models import (
    BazaarListing,
)

from real_estate.models import (
    Property,
    FlatType,
    PricingSlab,
)


class ProductDomain:

    def search_products(
        self,
        filters: dict,
        limit: int = 5,
    ):

        queryset = (
            Product.objects
            .filter(
                status="approved",
                is_active=True,
            )
            .select_related(
                "category",
                "subcategory",
                "brand",
                "company",
                "unit",
            )
            .prefetch_related(
                "images"
            )
        )

        query = filters.get("query")

        if query:
            queryset = queryset.filter(
                Q(name__icontains=query)
                | Q(description__icontains=query)
                | Q(specifications__icontains=query)
            )

        category = filters.get("category")

        if category:
            queryset = queryset.filter(
                category__name__icontains=category
            )

        subcategory = filters.get("subcategory")

        if subcategory:
            queryset = queryset.filter(
                subcategory__name__icontains=subcategory
            )

        brand = filters.get("brand")

        if brand:
            queryset = queryset.filter(
                brand__name__icontains=brand
            )

        min_price = filters.get("min_price")

        if min_price is not None:
            queryset = queryset.filter(
                final_price__gte=min_price
            )

        max_price = filters.get("max_price")

        if max_price is not None:
            queryset = queryset.filter(
                final_price__lte=max_price
            )

        if filters.get("in_stock"):
            queryset = queryset.filter(
                stock_quantity__gt=0
            )

        sort = filters.get("sort")

        if sort == "price_asc":
            queryset = queryset.order_by(
                "final_price"
            )

        elif sort == "price_desc":
            queryset = queryset.order_by(
                "-final_price"
            )

        else:
            queryset = queryset.order_by(
                "-is_featured",
                "-created_at"
            )

        products = queryset[:limit]

        cards = []

        for product in products:

            image = (
                product.images
                .order_by("id")
                .first()
            )

            image_url = (
                image.image_s3_key
                if image
                else product.thumbnail_s3_key
            )

            price = (
                product.get_final_price_with_offer()
            )

            cards.append(
                {
                    "ref": f"P{product.pk}",
                    "type": "product",
                    "slug": product.slug,
                    "title": product.name,
                    "price": str(price),
                    "image": image_url,
                    "url": (
                        "https://qnxmartb2b.com/"
                        f"product-details/{product.slug}"
                    ),
                }
            )

        return {
            "cards": cards,
            "items": cards,
        }

    def get_product(self, slug):

        product = (
            Product.objects
            .filter(
                slug=slug,
                status="approved",
                is_active=True,
            )
            .select_related(
                "category",
                "subcategory",
                "brand",
                "company",
                "unit",
            )
            .prefetch_related(
                "images",
                "variants",
            )
            .first()
        )

        if not product:
            return None

        return {
            "ref": f"P{product.pk}",
            "type": "product",
            "slug": product.slug,
            "title": product.name,
            "description": product.description,
            "price": str(
                product.get_final_price_with_offer()
            ),
            "stock_quantity": product.stock_quantity,
            "specifications": product.specifications or {},
            "url": (
                "https://qnxmartb2b.com/"
                f"product-details/{product.slug}"
            ),
        }

    def get_cart(self, user):

        cart_items = (
            CartItem.objects
            .filter(user=user)
            .select_related("product")
            .prefetch_related("product__images")
        )

        items = []

        for item in cart_items:

            product = item.product

            items.append(
                {
                    "product": product.name,
                    "slug": product.slug,
                    "quantity": item.quantity,
                    "price": str(
                        product.get_final_price_with_offer()
                    ),
                    "url": (
                        "https://qnxmartb2b.com/"
                        f"product-details/{product.slug}"
                    ),
                }
            )

        return {
            "items": items,
            "count": len(items),
        }

    def get_orders(
        self,
        user,
        limit=5,
    ):

        orders = (
            Order.objects
            .filter(user=user)
            .prefetch_related(
                "items__product"
            )
            .order_by("-created_at")[:limit]
        )

        result = []

        for order in orders:

            result.append(
                {
                    "order_id": order.order_id,
                    "status": order.status,
                    "payment_status": order.payment_status,
                    "payment_method": order.payment_method,
                    "total_amount": str(
                        order.total_amount
                    ),
                    "created_at": (
                        order.created_at.isoformat()
                    ),
                    "items": [
                        {
                            "product": item.product.name,
                            "quantity": item.quantity,
                            "price": str(item.price),
                        }
                        for item in order.items.all()
                    ],
                }
            )

        return {
            "orders": result,
        }

    def get_order(
        self,
        user,
        order_id,
    ):

        order = (
            Order.objects
            .filter(
                user=user,
                order_id=order_id,
            )
            .prefetch_related(
                "items__product"
            )
            .first()
        )

        if not order:
            return None

        return {
            "order_id": order.order_id,
            "status": order.status,
            "payment_status": order.payment_status,
            "payment_method": order.payment_method,
            "total_amount": str(
                order.total_amount
            ),
            "created_at": (
                order.created_at.isoformat()
            ),
            "items": [
                {
                    "product": item.product.name,
                    "quantity": item.quantity,
                    "price": str(item.price),
                }
                for item in order.items.all()
            ],
        }


class RealEstateDomain:

    def search_properties(
        self,
        filters: dict,
        limit: int = 5,
    ):

        queryset = (
            Property.objects
            .filter(
                status=Property.ListingStatus.ACTIVE,
                status_approved=True,
                is_verified=True,
            )
            .select_related(
                "builder",
            )
            .prefetch_related(
                "amenities",
                "flat_types",
                "pricing_slabs",
                "images",
            )
        )

        city = filters.get("city")

        if city:
            queryset = queryset.filter(
                city__icontains=city
            )

        area = filters.get("area")

        if area:
            queryset = queryset.filter(
                area__icontains=area
            )

        property_type = filters.get(
            "property_type"
        )

        if property_type:
            queryset = queryset.filter(
                property_type=property_type
            )

        transaction_type = filters.get(
            "transaction_type"
        )

        if transaction_type:
            queryset = queryset.filter(
                transaction_type=transaction_type
            )

        queryset = queryset.filter(
            Q(expiry_date__isnull=True)
            | Q(expiry_date__gt=timezone.now())
        )

        bhk = filters.get("bhk")

        if bhk:
            queryset = queryset.filter(
                flat_types__bedrooms=bhk,
                flat_types__is_available=True,
            )

        min_budget = filters.get(
            "min_budget"
        )

        max_budget = filters.get(
            "max_budget"
        )

        if min_budget is not None:
            queryset = queryset.filter(
                pricing_slabs__base_price__gte=min_budget,
                pricing_slabs__is_available=True,
            )

        if max_budget is not None:
            queryset = queryset.filter(
                pricing_slabs__base_price__lte=max_budget,
                pricing_slabs__is_available=True,
            )

        queryset = queryset.distinct()

        properties = queryset[:limit]

        cards = []

        for property_obj in properties:

            image = (
                property_obj.images
                .order_by(
                    "-is_primary",
                    "display_order",
                )
                .first()
            )

            cards.append(
                self.serialize_property(
                    property_obj,
                    image=image,
                )
            )

        return {
            "cards": cards,
            "items": cards,
        }

    def serialize_property(
        self,
        property_obj,
        image=None,
    ):

        flat_types = []

        for flat in property_obj.flat_types.filter(
            is_available=True
        ):

            flat_types.append(
                {
                    "type": flat.flat_type,
                    "bedrooms": flat.bedrooms,
                    "bathrooms": flat.bathrooms,
                    "area_sqft": (
                        str(flat.area_sqft)
                        if flat.area_sqft is not None
                        else None
                    ),
                }
            )

        pricing = []

        for slab in property_obj.pricing_slabs.filter(
            is_available=True
        ):

            pricing.append(
                {
                    "flat_type": (
                        slab.flat_type.flat_type
                    ),
                    "base_price": str(
                        slab.base_price
                    ),
                    "price_per_sqft": (
                        str(slab.price_per_sqft)
                        if slab.price_per_sqft is not None
                        else None
                    ),
                }
            )

        amenities = [
            amenity.name
            for amenity in property_obj.amenities.all()
            if amenity.is_active
        ]

        return {
            "ref": f"R{property_obj.pk}",
            "type": "property",
            "slug": property_obj.slug,
            "title": property_obj.title,
            "description": property_obj.description,
            "property_type": property_obj.property_type,
            "transaction_type": (
                property_obj.transaction_type
            ),
            "property_condition": (
                property_obj.property_condition
            ),
            "city": property_obj.city,
            "area": property_obj.area,
            "total_area": (
                str(property_obj.total_area)
                if property_obj.total_area is not None
                else None
            ),
            "builder": (
                property_obj.builder.name
                if property_obj.builder
                else None
            ),
            "amenities": amenities,
            "flat_types": flat_types,
            "pricing": pricing,
            "image": (
                image.image_s3_key
                if image
                else None
            ),
            "url": (
                "https://qnxmartb2b.com/"
                f"property-detail/{property_obj.slug}"
            ),
        }

    def get_property(self, slug):

        property_obj = (
            Property.objects
            .filter(
                slug=slug,
                status=Property.ListingStatus.ACTIVE,
                status_approved=True,
                is_verified=True,
            )
            .select_related("builder")
            .prefetch_related(
                "amenities",
                "flat_types",
                "pricing_slabs",
                "images",
            )
            .first()
        )

        if not property_obj:
            return None

        return self.serialize_property(
            property_obj
        )


class ReMartDomain:

    def search_listings(
        self,
        filters: dict,
        limit: int = 5,
    ):

        queryset = (
            BazaarListing.objects
            .filter(
                status="active"
            )
            .select_related(
                "category",
                "subcategory",
            )
        )

        query = filters.get("query")

        if query:
            queryset = queryset.filter(
                Q(title__icontains=query)
                | Q(description__icontains=query)
            )

        category = filters.get(
            "category"
        )

        if category:
            queryset = queryset.filter(
                category__name__icontains=category
            )

        subcategory = filters.get(
            "subcategory"
        )

        if subcategory:
            queryset = queryset.filter(
                subcategory__name__icontains=subcategory
            )

        city = filters.get("city")

        if city:
            queryset = queryset.filter(
                city__icontains=city
            )

        min_price = filters.get(
            "min_price"
        )

        if min_price is not None:
            queryset = queryset.filter(
                price__gte=min_price
            )

        max_price = filters.get(
            "max_price"
        )

        if max_price is not None:
            queryset = queryset.filter(
                price__lte=max_price
            )

        condition = filters.get(
            "condition"
        )

        if condition:
            queryset = queryset.filter(
                condition=condition
            )

        queryset = queryset.order_by(
            "-is_featured",
            "-created_at",
        )

        listings = queryset[:limit]

        cards = []

        for listing in listings:

            cards.append(
                {
                    "ref": f"M{listing.pk}",
                    "type": "remart_listing",
                    "slug": listing.slug,
                    "title": listing.title,
                    "description": listing.description,
                    "price": str(
                        listing.price
                    ),
                    "condition": listing.condition,
                    "city": listing.city,
                    "area": listing.area,
                    "attributes": listing.attributes,
                }
            )

        return {
            "cards": cards,
            "items": cards,
        }