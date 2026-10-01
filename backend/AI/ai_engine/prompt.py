PROPERTY_EXTRACTION_PROMPT = """
Extract all useful real-estate property information available in the document.

Rules:
- Extract only information explicitly present in the document.
- Use the exact field names defined in the schema.
- Return human-readable values, not database IDs.
- Do not guess or invent missing information.
- Preserve numeric values and explicitly stated units.
- Put units in the corresponding *_unit field.
- Preserve relationships between flat types, floors, and pricing.
- Extract builder/developer and agent/contact details when available.
- Extract location details including address, area, landmark, pincode, latitude, longitude, and map URL when available.
- Extract project details including towers, floors, construction status, possession date, and completion percentage when available.
- If a value is not found, return an empty value, null, or empty array as appropriate.
- Return only JSON matching the schema.
"""