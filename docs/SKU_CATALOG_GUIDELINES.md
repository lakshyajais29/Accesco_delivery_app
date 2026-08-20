# InstaStyle SKU Creation & Data Entry Guide

Welcome to the catalogue team. This document is everything you need to add a garment to InstaStyle correctly the first time.

Your entries land in `lib/services/catalog_service.dart` and feed **three surfaces at once**:

| Surface | What it shows |
|---|---|
| **Home & The Edit** | Product cards, rails (Just Dropped, Almost Gone, Trending), the full grid |
| **SwipeStyle** | The swipe deck — one garment per card, filtered by brand, price and category |
| **Thrift Marketplace** | Pre-loved listings, which additionally require condition and seller fields |

A field you leave blank doesn't just look empty — it silently removes a badge, breaks a filter, or hides a discount. The rules below say which.

---

## 1. How a SKU is shaped

Every garment is **one parent product plus one variant per size × colour combination**.

```
Merino Wool Overshirt  ← parent (1 record: name, brand, photo, description)
├── Charcoal / S       ← variant (own SKU, own stock, own price)
├── Charcoal / M
├── Camel / S
└── Camel / M          …and so on
```

4 sizes × 3 colours = **12 variants**. Each one needs its own row. This is the part people underestimate — budget time for it.

**Why it matters:** stock is tracked per variant. If Charcoal/M is sold out but Charcoal/L isn't, the app greys out only M. Enter stock as one number on the parent and that behaviour disappears.

---

## 2. Image guidelines — CRITICAL

InstaStyle is a premium app. The photograph is the product. One amateur image on a rail undermines every card beside it.

### Hard technical requirements

| Spec | Requirement | Why |
|---|---|---|
| **Aspect ratio** | **3:4 portrait** (e.g. 1024 × 1365) | The app crops every image to exactly 3:4 and centre-fills. A square or landscape photo gets its top and bottom sliced off. |
| **Minimum resolution** | 1024 px wide | Cards render up to 800 px on large phones. Below 1024 the image goes soft. |
| **Format** | JPG or WebP | |
| **File size** | Under 500 KB after compression | |
| **Colour profile** | sRGB | Anything else shifts colour on Android. |

> **Note on our existing catalogue:** current images are served at `?w=600&q=85`, which is **below** this standard. We're raising it to `w=1024&q=90` because the upcoming Virtual Try-On feature sends these images to an AI service, and 600 px produces visibly soft results. **All new entries must meet the 1024 px minimum.**

### Photographic standard

**Accepted:**
- **Studio** — seamless white, bone, or soft grey backdrop. Even, diffused lighting. No harsh shadows.
- **High-aesthetic street style** — natural light, intentional composition, an architectural or clean outdoor setting.
- **Flat-lay / ghost mannequin** — for accessories and knitwear, on a clean neutral surface, shot straight down.

**Rejected — do not submit:**
- Mirror selfies, phone-flash photos, or anything shot in a bedroom or changing room
- Blurry, pixelated, low-resolution, or upscaled images
- Cluttered backgrounds — visible hangers, rails, laundry, other people, retail signage
- Heavy filters, strong colour grading, or beauty-smoothing
- Watermarks, logos, price stickers, or text overlays of any kind
- Screenshots, collages, or images with white borders baked in

### Framing and colour

- The garment occupies **at least 70% of the frame height**. Don't leave the model floating in empty space.
- Full garment visible — nothing cropped out of frame at the hem or sleeve.
- **The photo must show the actual colourway.** If you list "Camel", the photo is the camel one. Do not reuse the black photo for every colour.

### Per-variant images

`ProductVariant.imageUrl` currently sits empty across the whole catalogue, so **every colour falls back to the parent photo**. A customer tapping "Sage" still sees the charcoal jacket.

**Going forward: fill `imageUrl` on at least one variant per colourway.** This is the single highest-impact improvement you can make to the existing catalogue.

---

## 3. Categories & sub-categories

### Department (`gender`)

Only **three** values are supported by the app today:

| Value | Use for |
|---|---|
| `women` | Womenswear |
| `men` | Menswear |
| `unisex` | Genuinely unsized-by-gender pieces — most accessories, many hoodies |

> ⚠️ **Kids and Beauty are not yet supported.** The home screen shows Kids/Beauty/Home tiles, but they run a text search rather than a real department filter — there is no `gender` value to assign. **Do not create Kids or Beauty products yet.** Engineering needs to extend the model first (see §9).

### Sub-category (`category`)

These thirteen values are live. **Use one of them, spelled exactly as shown** — the Browse and Swipe filters are built from these strings, so `Denim` and `denim` become two separate filters.

| | | |
|---|---|---|
| Accessories | Blazers | Bottoms |
| Co-ords | Denim | Dresses |
| Ethnic | Footwear | Hoodies |
| Jackets | Outerwear | Streetwear |
| Tops | | |

**Need a category that isn't listed** — Winterwear, Vintage, Loungewear? Don't invent it. Raise it with the catalogue lead first; adding one is a code change, and a typo'd category makes a product unreachable through filters.

### Brand (`brand`)

Always **UPPERCASE**, exactly as registered. Current roster:

`ATELIER SUR` · `CASA MODAS` · `DECO NOIR` · `INDIRA & CO` · `MAISON KAIRA` · `NORDVIK CO` · `RAW & REFINED` · `STRIDE ELITE`

---

## 4. The SKU data structure

### 4a. Parent product fields

| Field | Required | Format | Notes |
|---|---|---|---|
| `id` | ✅ | `XXX-YY` | 3-letter product code + 2-letter brand code. `PBL-AS` = **P**ower **BL**azer, **A**telier **S**ur. Must be unique across the catalogue. |
| `name` | ✅ | Title Case | The garment as a shopper would say it. "Power Structured Blazer", not "BLAZER-WOMENS-BLK-01". |
| `brand` | ✅ | UPPERCASE | From the roster above. |
| `category` | ✅ | Exact string | From the thirteen above. |
| `gender` | ✅ | `women` / `men` / `unisex` | |
| `defaultImageUrl` | ✅ | URL | The hero shot. 3:4, ≥1024 px. |
| `description` | ✅ | 2 sentences | See §7. |
| `sizes` | ✅ | List | From `XS S M L XL XXL`. List only sizes that genuinely exist. |
| `colors` | ✅ | Name + hex | `VariantColor('Camel', '#C19A6B')`. The hex paints the colour swatch — sample it from the actual garment. |
| `originalPriceFormatted` | ➖ | `'₹12,000'` | **The pre-discount price.** Omit entirely if the item isn't discounted. See money rules below. |
| `stock` | ✅ | Integer | Total across variants. Drives the "Only N left" urgency tag when under 4. |
| `isNew` | ➖ | true/false | Shows the **New** badge. |
| `droppedMinsAgo` | ➖ | Integer | Minutes since launch. Powers "Dropped 25m ago" and the Just Dropped rail ordering. |

### 4b. Variant fields — one row per size × colour

| Field | Required | Format | Notes |
|---|---|---|---|
| `sku` | ✅ | `PARENT-CLR-SIZE-NNN` | `PBL-AS-BLK-S-101`. Colour as a 3-letter code; `NNN` is a per-product block that increments by 10 per colourway (101–104 black, 111–114 ivory, 121–124 blush). **This is the identifier that travels to the cart — it must be unique app-wide.** |
| `parentId` | ✅ | Parent's `id` | Must match exactly. |
| `size` | ✅ | `XS`–`XXL` | |
| `colorName` | ✅ | Title Case | Must match the parent's `colors` entry. |
| `colorHex` | ✅ | `#RRGGBB` | Must match the parent's `colors` entry. |
| `stock` | ✅ | Integer | 0 is valid — it renders as a struck-through, unselectable size. |
| `priceInPaise` | ✅ | Integer | **See money rules.** |
| `imageUrl` | ➖ | URL | The colourway's own photo. Strongly encouraged. |

The map key for each variant is `SIZE__#HEX` — note the **double underscore**: `'M__#C19A6B'`.

### 4c. Money rules — read twice

**Prices are stored in paise, as integers.** Multiply rupees by 100.

| Displayed | You enter |
|---|---|
| ₹6,499 | `649900` |
| ₹840 | `84000` |
| ₹22,000 | `2200000` |

Three rules that silently break the discount UI if you get them wrong:

1. **`originalPriceFormatted` is a *string* with the ₹ symbol and Indian comma grouping** — `'₹8,999'`. The app parses the digits back out to compute the discount percentage. `8999` or `Rs 8999` will not work.
2. **The original price must be strictly higher than the lowest variant price.** If it's equal or lower, the app hides the discount rather than printing "0% off" — so the badge just silently vanishes.
3. **Variants of different colours may carry different prices.** The card always displays the *lowest* variant price. If Camel costs more than Charcoal, the card shows the Charcoal price.

The discount percentage is **calculated, never entered**: `(original − lowest variant price) ÷ original`, rounded.

---

## 5. Tags — how they actually work

Your brief mentions a Tags field (Trending, Bestselling, New In). Important: **there is no `tags` field in the app.** Those badges are *derived* from numeric signals, which means you control them by setting the right number — not by typing a word.

| Badge in the app | Driven by | Rule |
|---|---|---|
| **New** | `isNew` | Set `true`. |
| **"Dropped 25m ago"** | `droppedMinsAgo` | Minutes since launch. Also orders the Just Dropped rail. |
| **Sale** | `originalPriceFormatted` | Present = badge appears. Absent = no badge. |
| **Trending / `#1`** | `cityRank` | 1 = top of the city. `0` means unranked and sorts last. |
| **"31 ordered today"** *(bestselling)* | `orderedToday` | Units sold today. |
| **"Only 3 left"** | `stock` | Appears automatically under 4. |
| **"8 viewing now"** | `viewersNow` | Live social proof. |
| **Vibe Check rail** | `friendVotes` | |

**Guidance:** these are urgency signals, and the design rule is *at most two per card*. Don't set every field on every product — a catalogue where everything is trending, selling out and brand new reads as noise, and shoppers stop believing any of it. Reserve `cityRank` for genuine top performers.

---

## 6. Condition — Thrift items only

Main-catalogue items are new by definition and need none of these. **Pre-loved listings require all four.**

| Field | Values | Notes |
|---|---|---|
| `conditionLabel` | `Like New` · `Gently Used` · `Vintage Find` | Customer-facing. Must be one of these three exactly. |
| `conditionGrade` | `Grade A` · `Grade B` · `Grade C` | Internal QC grade shown on the listing. |
| `isVerifiedItem` | true/false | Only `true` after the item passes physical inspection. |
| `sellerName` / `sellerRating` / `isVerifiedSeller` | | Required for the seller strip on the listing. |

**What each label means:**

- **Like New** — worn once or twice, or never. No visible wear, no pilling, tags may still be attached.
- **Gently Used** — worn regularly but well cared for. Minor, non-obvious signs of wear. No holes, stains, or repairs.
- **Vintage Find** — genuinely old (20+ years) and valued for it. Character marks are acceptable and should be described honestly in the description.

> ⚠️ Your brief lists **"Brand New"** as a condition. The app doesn't have that value — it has **Vintage Find** as the third option. A genuinely unworn, tagged thrift item should be entered as **Like New**. If we want a true "Brand New / With Tags" grade, that's a code change (see §9).

**Rule: never flatter the condition.** A "Like New" item that arrives visibly worn generates a return, a refund and a bad review. Grade down when in doubt.

---

## 7. Writing the description

**Two sentences. 30–55 words.** Sentence one: what it is and what it's made of. Sentence two: how it feels to wear, or where it belongs.

Our house voice is *specific and material*, never breathless.

✅ **Good:**
> Cut from a fluid ponte-knit blend with a 4-button double-breasted front, this blazer delivers boardroom authority in equal measure. Notched lapels and a cinched back seam create an architectural silhouette that photographs beautifully under any light.

❌ **Avoid:**
> Amazing must-have blazer!! Perfect for any occasion. Buy now, limited stock!!

Rules:
- Name the **fabric** — ponte knit, dupion silk, brushed cotton twill. This is the single biggest quality signal.
- No ALL CAPS, no exclamation marks, no emoji.
- Never mention price, discounts, or stock — those are separate fields and they change.
- Don't repeat the product name verbatim; it already sits directly above.

---

## 8. Example of a perfect entry

**Product:** Merino Wool Overshirt · NORDVIK CO · Men's Outerwear · ₹6,499 (was ₹8,999) · 2 colourways × 4 sizes

### As a table

| Field | Value |
|---|---|
| ID | `MWO-NC` |
| Name | Merino Wool Overshirt |
| Brand | `NORDVIK CO` |
| Category | `Outerwear` |
| Department | `men` |
| Image | `https://cdn.instastyle.in/catalog/mwo-nc/hero.jpg?w=1024&q=90` |
| Current price | ₹6,499 → `649900` paise |
| Original price | `'₹8,999'` → renders **28% OFF** |
| Sizes | S, M, L, XL |
| Colours | Charcoal `#2E2E2E`, Camel `#C19A6B` |
| Condition | *n/a — main catalogue* |
| Tags | `isNew: true`, `droppedMinsAgo: 45`, `cityRank: 3`, `orderedToday: 18` |
| Total stock | 21 |

### As JSON

```json
{
  "id": "MWO-NC",
  "name": "Merino Wool Overshirt",
  "brand": "NORDVIK CO",
  "category": "Outerwear",
  "gender": "men",
  "defaultImageUrl": "https://cdn.instastyle.in/catalog/mwo-nc/hero.jpg?w=1024&q=90",
  "description": "Woven from 100% extra-fine merino with a soft brushed face and horn-effect buttons, this overshirt sits comfortably between a shirt and a jacket. Light enough for an office layer, warm enough to be the outer piece well into November.",
  "originalPriceFormatted": "₹8,999",
  "sizes": ["S", "M", "L", "XL"],
  "colors": [
    { "name": "Charcoal", "hex": "#2E2E2E" },
    { "name": "Camel",    "hex": "#C19A6B" }
  ],
  "isNew": true,
  "droppedMinsAgo": 45,
  "stock": 21,
  "cityRank": 3,
  "orderedToday": 18,
  "variantMap": {
    "S__#2E2E2E":  { "sku": "MWO-NC-CHR-S-501",  "parentId": "MWO-NC", "size": "S",  "colorName": "Charcoal", "colorHex": "#2E2E2E", "stock": 3, "priceInPaise": 649900, "imageUrl": "https://cdn.instastyle.in/catalog/mwo-nc/charcoal.jpg?w=1024&q=90" },
    "M__#2E2E2E":  { "sku": "MWO-NC-CHR-M-502",  "parentId": "MWO-NC", "size": "M",  "colorName": "Charcoal", "colorHex": "#2E2E2E", "stock": 5, "priceInPaise": 649900 },
    "L__#2E2E2E":  { "sku": "MWO-NC-CHR-L-503",  "parentId": "MWO-NC", "size": "L",  "colorName": "Charcoal", "colorHex": "#2E2E2E", "stock": 4, "priceInPaise": 649900 },
    "XL__#2E2E2E": { "sku": "MWO-NC-CHR-XL-504", "parentId": "MWO-NC", "size": "XL", "colorName": "Charcoal", "colorHex": "#2E2E2E", "stock": 0, "priceInPaise": 649900 },
    "S__#C19A6B":  { "sku": "MWO-NC-CML-S-511",  "parentId": "MWO-NC", "size": "S",  "colorName": "Camel",    "colorHex": "#C19A6B", "stock": 2, "priceInPaise": 679900, "imageUrl": "https://cdn.instastyle.in/catalog/mwo-nc/camel.jpg?w=1024&q=90" },
    "M__#C19A6B":  { "sku": "MWO-NC-CML-M-512",  "parentId": "MWO-NC", "size": "M",  "colorName": "Camel",    "colorHex": "#C19A6B", "stock": 4, "priceInPaise": 679900 },
    "L__#C19A6B":  { "sku": "MWO-NC-CML-L-513",  "parentId": "MWO-NC", "size": "L",  "colorName": "Camel",    "colorHex": "#C19A6B", "stock": 3, "priceInPaise": 679900 },
    "XL__#C19A6B": { "sku": "MWO-NC-CML-XL-514", "parentId": "MWO-NC", "size": "XL", "colorName": "Camel",    "colorHex": "#C19A6B", "stock": 0, "priceInPaise": 679900 }
  }
}
```

Note in this example: Camel is ₹300 dearer than Charcoal, so the card displays **₹6,499** (the lowest). Two variants are at zero stock and will render struck through. The discount reads 28% — derived from ₹8,999 against ₹6,499, not typed by hand.

---

## 9. Pre-submission checklist

Run this before every batch. Most rejected entries fail on items 3, 6, or 9.

- [ ] `id` is unique and follows `XXX-YY`
- [ ] Every variant `sku` is unique app-wide
- [ ] **Every image is 3:4 portrait and at least 1024 px wide**
- [ ] No mirror selfies, watermarks, or cluttered backgrounds
- [ ] Each colourway has its own photo on at least one variant
- [ ] **Prices are in paise** (rupees × 100)
- [ ] `originalPriceFormatted` includes `₹` and commas, and is **higher** than the lowest variant price
- [ ] `category` and `brand` match the approved lists character for character
- [ ] Every size × colour combination has a variant row — none missing
- [ ] `colorName` and `colorHex` on each variant match the parent's `colors` list
- [ ] Description is 2 sentences, names the fabric, no hype
- [ ] Thrift only: `conditionLabel`, `conditionGrade`, `isVerifiedItem` and seller fields all present
- [ ] At most two urgency signals set per product

---

## 10. Open items for engineering

Flagged during this review — not blockers for menswear/womenswear entry, but they constrain what you can enter today.

| # | Item | Impact |
|---|---|---|
| 1 | No `gender` value for **Kids** or **Beauty** | Those departments can't be populated. The home screen tiles currently run a text search instead. |
| 2 | No **"Brand New / With Tags"** condition | Unworn thrift items have to be filed as *Like New*. |
| 3 | `ProductVariant.imageUrl` unused catalogue-wide | Every colourway shows the parent photo. |
| 4 | Catalogue images served at 600 px | Below the 1024 px that Virtual Try-On needs. Existing entries need re-sourcing. |
| 5 | No `tags` array | Merchandising is driven only by numeric signals, so a curated "Editor's Pick"-style tag isn't expressible. |

---

*Questions on any specific entry — ask before submitting rather than guessing. A wrong `category` string makes a product invisible to filters, and that's much harder to spot after the fact than to prevent.*
