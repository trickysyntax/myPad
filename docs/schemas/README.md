# myPad Asset JSON Schema v1

Definitive JSON Schema for Asset (AssetTemplate) and AssetFinish objects in the myPad system.

## Files

- `docs/schemas/asset-schema-v1.json` — the schema document (Draft 2020-12)

## What's covered

The schema defines the following shapes:

| Definition | Purpose | Endpoint |
|---|---|---|
| `AssetTemplateSummary` | Asset as returned in list/search results | `GET /api/assets` |
| `AssetTemplateDetail` | Asset with nested finishes | `GET /api/assets/{id}` |
| `AssetFinish` | Individual finish/colorway | `GET /api/assets/{id}/finishes` |
| `PaginatedAssetsResponse` | Pagination wrapper for asset list | `GET /api/assets` |
| `FinishesListResponse` | Wrapper for finishes list | `GET /api/assets/{id}/finishes` |
| `AssetCreateRequest` | Request body for creating assets | `POST /api/assets` |
| `AssetUpdateRequest` | Request body for updating assets | `PUT /api/assets/{id}` |
| `VendorRef` | Lightweight vendor reference nested into assets | — |

## Key field details

**AssetTemplate** (Summary and Detail share the same 19 fields; Detail adds `finishes`):

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID string | yes | Primary key |
| `vendor_id` | UUID string or null | no | FK to vendors; nullable as of ee77557edcc9 |
| `vendor` | VendorRef or null | no | Joined at query time |
| `name` | string (max 255) | yes | Required on create |
| `sku` | string (max 100) or null | no | |
| `category` | string (max 100) or null | no | e.g. Furniture, Lighting, Textiles |
| `description` | string or null | no | Free text |
| `msrp` | number or null | no | Numeric(12,2) in DB |
| `trade_price` | number or null | no | Numeric(12,2) in DB |
| `lead_time_weeks` | integer or null | no | |
| `minimum_order` | string (max 255) or null | no | |
| `dimensions` | string (max 255) or null | no | |
| `care_instructions` | string or null | no | |
| `image_urls` | array of URI strings | no | Default: [] |
| `spec_sheet_url` | URI string or null | no | max 500 chars |
| `is_discontinued` | boolean | yes | Soft-delete flag; default false |
| `finish_count` | integer | yes | Computed server-side |
| `created_at` | ISO 8601 datetime or null | no | |
| `updated_at` | ISO 8601 datetime or null | no | |
| `finishes` | array of AssetFinish | detail only | Included in detail endpoint |

**AssetFinish:**

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID string | yes | |
| `asset_template_id` | UUID string | yes | FK to asset_templates |
| `name` | string (max 255) | yes | |
| `finish_type` | string (max 50) | yes | Default: "finish" |
| `upcharge_pct` | number or null | no | Numeric(5,2) |
| `grade` | string (max 20) or null | no | |
| `width` | string (max 50) or null | no | |
| `repeat` | string (max 50) or null | no | |
| `railroad` | boolean or null | no | |
| `source` | string (max 255) or null | no | |
| `pattern_color` | string (max 255) or null | no | |
| `in_stock` | boolean | yes | Default: true |
| `swatch_image_url` | URI string or null | no | max 500 chars |
| `sort_order` | integer (>= 0) | yes | Default: 0 |
| `created_at` | ISO 8601 datetime or null | no | |

## Validation

### CLI (Python)

```bash
pip install jsonschema
python3 -c "
import json, jsonschema
schema = json.load(open('docs/schemas/asset-schema-v1.json'))
instance = json.loads('{ ... }')  # your asset JSON
jsonschema.validate(instance, schema['\$defs']['AssetTemplateSummary'])
print('Valid!')
"
```

### In JavaScript/Node.js

```bash
npm install ajv
```

```js
const Ajv = require('ajv/dist/2020');
const schema = require('./docs/schemas/asset-schema-v1.json');
const ajv = new Ajv();
const validate = ajv.getSchema('#/$defs/AssetTemplateSummary');
if (validate(asset)) { console.log('Valid!'); }
```

### Online

Paste the contents of `asset-schema-v1.json` into https://www.jsonschemavalidator.net/ (switch to Draft 2020-12).

## Version history

- **v1** (2026-05-19) — Initial release. Covers all AssetTemplate and AssetFinish fields from the production API. Validated against 5 live assets with 5 finishes.

## Source of truth

This schema is derived from:
- `app/models/asset_template.py` and `app/models/asset_finish.py` (SQLAlchemy models)
- `app/api/assets.py` and `app/api/finishes.py` (API endpoints + serialization)
- `alembic/versions/ad1ffbcc7a0f_initial.py` (DB migration)
- `alembic/versions/ee77557edcc9_nullable_vendor_id.py` (vendor_id nullable migration)
- `MyPadKit` Swift models (AssetTemplateSummary, AssetTemplateDetail, AssetFinishSummary)
- Live production data at mypad.susie.cloud
