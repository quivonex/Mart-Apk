PROPERTY_SCHEMA = {
    "type": "object",
    "properties": {

        # =========================================================
        # PROPERTY BASIC INFORMATION
        # =========================================================

        "title": {
            "type": "string",
            "description": "Property or project name."
        },

        "description": {
            "type": "string",
            "description": "Property or project description."
        },

        "property_type": {
            "type": "string",
            "description": "Property type such as flat, villa, plot, commercial, shop, office, warehouse, etc."
        },

        "transaction_type": {
            "type": "string",
            "description": "Transaction type such as sale, rent, lease, or pg."
        },

        "status": {
            "type": "string",
            "description": "Property/project status if explicitly mentioned."
        },

        # =========================================================
        # LOCATION
        # =========================================================

        "city": {
            "type": "string",
            "description": "City of the property/project."
        },

        "area": {
            "type": "string",
            "description": "Locality, area, neighborhood, or suburb."
        },

        "address": {
            "type": "string",
            "description": "Complete property/project address."
        },

        "landmark": {
            "type": "string",
            "description": "Nearby landmark."
        },

        "pincode": {
            "type": "string",
            "description": "Postal/PIN code."
        },

        "latitude": {
            "type": "number",
            "description": "Latitude if explicitly available."
        },

        "longitude": {
            "type": "number",
            "description": "Longitude if explicitly available."
        },

        "google_location_url": {
            "type": "string",
            "description": "Google Maps/location URL if explicitly available."
        },

        # =========================================================
        # PROPERTY / PROJECT SIZE
        # =========================================================

        "total_area": {
            "type": "number",
            "description": "Total property/project area as a number."
        },

        "total_area_unit": {
            "type": "string",
            "description": "Unit of total_area such as acres, sqft, sqm, hectares, etc."
        },

        "plot_area": {
            "type": "number",
            "description": "Plot/land area."
        },

        "plot_area_unit": {
            "type": "string",
            "description": "Unit of plot_area."
        },

        "total_floors": {
            "type": "integer",
            "description": "Total number of floors."
        },

        "total_towers": {
            "type": "integer",
            "description": "Total number of towers/buildings."
        },

        # =========================================================
        # BUILDER / DEVELOPER
        # =========================================================

        "builder": {
            "type": "object",
            "description": "Builder/developer information found in the document.",
            "properties": {

                "name": {
                    "type": "string",
                    "description": "Builder/developer/company name."
                },

                "short_info": {
                    "type": "string",
                    "description": "Short description/about the builder if mentioned."
                },

                "website": {
                    "type": "string",
                    "description": "Builder/developer website."
                },

                "email": {
                    "type": "string",
                    "description": "Builder/developer email."
                },

                "phone": {
                    "type": "string",
                    "description": "Builder/developer phone number."
                }
            },
            "required": [
                "name",
                "short_info",
                "website",
                "email",
                "phone"
            ]
        },

        # =========================================================
        # AGENT / CONTACT
        # =========================================================

        "agent": {
            "type": "object",
            "description": "Agent/contact information if found in the document.",
            "properties": {

                "name": {
                    "type": "string",
                    "description": "Agent name."
                },

                "email": {
                    "type": "string",
                    "description": "Agent email."
                },

                "phone": {
                    "type": "string",
                    "description": "Agent phone number."
                }
            },
            "required": [
                "name",
                "email",
                "phone"
            ]
        },

        # =========================================================
        # RERA
        # =========================================================

        "rera_number": {
            "type": "string",
            "description": "RERA registration number."
        },

        "rera_qr_code": {
            "type": "string",
            "description": "Readable RERA QR-code URL if available."
        },

        "rera_website": {
            "type": "string",
            "description": "RERA website URL."
        },

        "rera_additional_urls": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "description": "Additional RERA-related URLs."
        },

        "property_website_url": {
            "type": "string",
            "description": "Property/project website URL."
        },

        # =========================================================
        # CONSTRUCTION / POSSESSION
        # =========================================================

        "is_under_construction": {
            "type": "boolean",
            "description": "Whether the property/project is under construction."
        },

        "possession_date": {
            "type": "string",
            "description": "Expected possession date."
        },

        "completion_percentage": {
            "type": "integer",
            "description": "Construction/project completion percentage from 0 to 100."
        },

        # =========================================================
        # PROPERTY FLAGS
        # =========================================================

        "is_featured": {
            "type": "boolean",
            "description": "Whether the property is explicitly marked as featured."
        },

        "is_verified": {
            "type": "boolean",
            "description": "Whether the property/project is explicitly marked as verified."
        },

        "is_negotiable": {
            "type": "boolean",
            "description": "Whether price is explicitly mentioned as negotiable."
        },

        # =========================================================
        # AMENITIES
        # =========================================================

        "amenities": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "description": "Human-readable amenity names found in the document."
        },

        # =========================================================
        # ADDITIONAL FEATURES
        # =========================================================

        "features": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {

                    "name": {
                        "type": "string"
                    },

                    "value": {
                        "type": "string"
                    }
                },
                "required": [
                    "name",
                    "value"
                ]
            },
            "description": "Additional useful property/project information without a dedicated field."
        },

        # =========================================================
        # FLAT TYPES
        # =========================================================

        "flat_types": {
            "type": "array",
            "description": "Different apartment/flat configurations.",
            "items": {
                "type": "object",
                "properties": {

                    "flat_type": {
                        "type": "string",
                        "description": "Example: 1 BHK, 2 BHK, 3 BHK, 4 BHK."
                    },

                    "area_sqft": {
                        "type": "number",
                        "description": "Flat area."
                    },

                    "area_sqft_unit": {
                        "type": "string",
                        "description": "Unit of flat area."
                    },

                    "carpet_area": {
                        "type": "number",
                        "description": "Carpet area."
                    },

                    "carpet_area_unit": {
                        "type": "string",
                        "description": "Unit of carpet area."
                    },

                    "built_up_area": {
                        "type": "number",
                        "description": "Built-up area."
                    },

                    "built_up_area_unit": {
                        "type": "string",
                        "description": "Unit of built-up area."
                    },

                    "balcony_area": {
                        "type": "number",
                        "description": "Balcony area."
                    },

                    "balcony_area_unit": {
                        "type": "string",
                        "description": "Unit of balcony area."
                    },

                    "bedrooms": {
                        "type": "integer"
                    },

                    "bathrooms": {
                        "type": "integer"
                    },

                    "balconies": {
                        "type": "integer"
                    },

                    "kitchens": {
                        "type": "integer"
                    },

                    "parking_count": {
                        "type": "integer"
                    },

                    "description": {
                        "type": "string"
                    },

                    "is_available": {
                        "type": "boolean"
                    }
                },

                "required": [
                    "flat_type"
                ]
            }
        },

        # =========================================================
        # FLOOR INFORMATION
        # =========================================================

        "floors": {
            "type": "array",
            "description": "Floor-wise information.",
            "items": {
                "type": "object",
                "properties": {

                    "floor_number": {
                        "type": "integer"
                    },

                    "floor_name": {
                        "type": "string"
                    },

                    "total_units": {
                        "type": "integer"
                    },

                    "available_units": {
                        "type": "integer"
                    },

                    "expected_completion_date": {
                        "type": "string"
                    }
                },

                "required": [
                    "floor_number"
                ]
            }
        },

        # =========================================================
        # PRICING
        # =========================================================

        "pricing_slabs": {
            "type": "array",
            "description": "Pricing information by floor and/or flat type.",
            "items": {
                "type": "object",
                "properties": {

                    "floor": {
                        "type": "integer"
                    },

                    "flat_type": {
                        "type": "string"
                    },

                    "base_price": {
                        "type": "number"
                    },

                    "base_price_unit": {
                        "type": "string",
                        "description": "Currency of base price such as INR, USD, EUR."
                    },

                    "price_per_sqft": {
                        "type": "number"
                    },

                    "price_per_sqft_unit": {
                        "type": "string",
                        "description": "Unit/currency such as INR/sqft."
                    },

                    "booking_amount": {
                        "type": "number"
                    },

                    "booking_amount_unit": {
                        "type": "string",
                        "description": "Currency of booking amount."
                    },

                    "discount_percentage": {
                        "type": "number"
                    },

                    "gst_percentage": {
                        "type": "number"
                    },

                    "payment_schedule": {
                        "type": "object",
                        "properties": {

                            "booking": {
                                "type": "string"
                            },

                            "agreement": {
                                "type": "string"
                            },

                            "possession": {
                                "type": "string"
                            },

                            "other": {
                                "type": "string"
                            }
                        }
                    },

                    "additional_charges": {
                        "type": "object",
                        "properties": {

                            "parking": {
                                "type": "string"
                            },

                            "maintenance": {
                                "type": "string"
                            },

                            "floor_rise": {
                                "type": "string"
                            },

                            "clubhouse": {
                                "type": "string"
                            },

                            "registration": {
                                "type": "string"
                            },

                            "other": {
                                "type": "string"
                            }
                        }
                    },

                    "is_available": {
                        "type": "boolean"
                    }
                },

                "required": [
                    "base_price"
                ]
            }
        }
    },

    # =============================================================
    # REQUIRED FIELDS
    # =============================================================

    "required": [
        "title",
        "property_type"
    ]
}