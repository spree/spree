# @spree/core

The shared foundation of [Spree Commerce](https://spreecommerce.org) for TypeScript and JavaScript: the code lists the Spree API speaks, exact money arithmetic, and the filter vocabulary of its list endpoints.

It has no dependencies and makes no network calls, so it runs anywhere JavaScript does: browsers, Node.js, edge runtimes, React Native and build scripts. The [Store](https://www.npmjs.com/package/@spree/sdk), [Admin](https://www.npmjs.com/package/@spree/admin-sdk) and [Seller](https://www.npmjs.com/package/@spree/seller-sdk) SDKs are built on it and re-export its code lists and money helpers. Install it on its own when you need those without an API client — in a checkout widget, a feed generator, a test suite or your own backend.

```bash
npm install @spree/core
```

> **Developer Preview.** `@spree/core` is on the 0.x line, published under the `next` dist-tag (`npm install @spree/core@next`). Its API may change between minor versions until 1.0, so pin an exact version.

## Contents

- [Code lists](#code-lists) — countries, currencies, locales, weight and dimension units
- [Money](#money) — exact arithmetic and formatting for decimal-string amounts
- [Filters](#filters) — types for the queries Spree list endpoints accept
- [Compatibility](#compatibility)

## Code lists

Every country, currency, locale and unit Spree accepts, as closed lists generated from the Spree API reference. Each list is both a value you can iterate and a type, and every code is documented with its English name, so your editor shows "US Dollar" when you hover `USD`.

| List | Contains | Example |
| --- | --- | --- |
| `CountryCode` | 240 ISO 3166-1 alpha-2 country codes | `CountryCode.US` → `'US'` |
| `CurrencyCode` | 178 ISO 4217 currency codes | `CurrencyCode.EUR` → `'EUR'` |
| `LocaleCode` | 202 locale codes | `LocaleCode.pt_BR` → `'pt-BR'` |
| `WeightUnit` | `g`, `kg`, `lb`, `oz` | `WeightUnit.kg` → `'kg'` |
| `DimensionUnit` | `mm`, `cm`, `in`, `ft` | `DimensionUnit.cm` → `'cm'` |

```typescript
import { CurrencyCode, WeightUnit } from '@spree/core';

// As a type: only codes Spree accepts compile.
function setCurrency(currency: CurrencyCode) {}
setCurrency('EUR');
setCurrency('EURO'); // Type error

// As a value: build a picker from the full list.
const options = Object.values(WeightUnit); // ['g', 'kg', 'lb', 'oz']
```

A locale with a region uses a hyphen in its value and an underscore in its key, so `LocaleCode.pt_BR` is `'pt-BR'`.

## Money

Spree sends and accepts every amount as a decimal string such as `"1234.56"`, never as a JavaScript number. A number cannot hold most decimal amounts exactly (`0.1 + 0.2` is `0.30000000000000004`), and those errors grow into lost cents on totals, refunds and payouts.

These helpers work on the strings directly, without converting them to numbers, so every result is exact:

```typescript
import { sumMoney, subtractMoney, multiplyMoney, compareMoney, formatMoney } from '@spree/core';

const subtotal = sumMoney(['19.99', '5.01'], 'USD'); // '25.00'
const lineTotal = multiplyMoney('9.99', 3, 'USD'); // '29.97'
const balance = subtractMoney('10.00', '0.01'); // '9.99'

if (compareMoney(subtotal, '25.00') >= 0) {
  // free shipping
}

formatMoney(subtotal, 'USD', 'en-US'); // '$25.00'
```

| Function | What it does |
| --- | --- |
| `sumMoney(values, currency?)` | Adds amounts. Blank values (`null`, `undefined`, `''`) count as zero. |
| `subtractMoney(a, b, currency?)` | `a` minus `b`. |
| `multiplyMoney(value, quantity, currency?)` | An amount times a whole number. A fractional quantity throws an error. |
| `negateMoney(value)` | Flips the sign: `'5.00'` → `'-5.00'`. |
| `compareMoney(a, b)` | `-1`, `0` or `1`. Decimals don't matter: `'10.0'` equals `'10.00'`. |
| `isZeroMoney(value)` | Whether an amount is zero. Blank values count as zero. |
| `isDecimalString(value)` | Whether a value is a plain decimal string. `'19.99'` is; `'19,99'` and the number `19.99` are not. |
| `decimalPlaces(currency)` | How many decimals a currency uses: 2 for USD, 0 for JPY, 3 for KWD. An unknown code answers 2. |
| `formatMoney(amount, currency, locale?, options?)` | Formats an amount for display in a language. |

### Nothing is rounded away

Arithmetic never rounds. A result keeps the most decimals any input has and, when you pass a currency, at least that currency's decimals:

```typescript
sumMoney(['1.5', '2.5'], 'USD'); // '4.00'  — padded to the currency's 2 decimals
sumMoney(['1000'], 'JPY'); // '1000'  — the yen has no decimals
multiplyMoney('19.9990', 3); // '59.9970' — a unit price keeps its 4 decimals
```

Rounding happens once, when you display the amount.

### Formatting

`formatMoney` shows an amount in a currency and language, using the currency's own number of decimals:

```typescript
formatMoney('1234.5', 'USD', 'en-US'); // '$1,234.50'
formatMoney('1234.5', 'EUR', 'de-DE'); // '1.234,50 €'
formatMoney('1500', 'JPY', 'ja-JP'); // '￥1,500'
formatMoney('0.0125', 'USD', 'en-US', { unitPrice: true }); // '$0.0125'
```

- Leave out the locale to use the reader's own language.
- `unitPrice: true` keeps up to 4 decimals, for prices per gram or per unit.
- A missing or malformed amount formats as an empty string, so a page never shows `NaN`.
- An amount that rounds to zero shows no minus sign: `'-0.001'` formats as `'$0.00'`.

`CURRENCY_EXPONENTS` exposes the full currency decimals table. The Spree server reads the same table, so the server and your client always agree on a currency's decimals.

## Filters

Spree list endpoints accept filters named after an attribute and a condition: `name_cont` (name contains), `price_gteq` (price at least), `status_in` (status is one of), `deleted_at_null` (not deleted). These types build exact TypeScript types for those queries, so a misspelled filter or a value of the wrong kind fails to compile.

The SDKs already type every list method this way. Use these types to describe queries of your own, such as a saved search or a URL you build by hand:

```typescript
import type { RangeFilters, SortKey, TextFilters } from '@spree/core';

type ProductQuery = TextFilters<'name' | 'sku'> &
  RangeFilters<'price'> & {
    sort?: SortKey<'name' | 'price' | 'created_at'>;
  };

const query: ProductQuery = {
  name_cont: 'shirt',
  price_gteq: '10.00',
  sort: '-price',
};
```

| Type | For | Conditions |
| --- | --- | --- |
| `TextFilters<Attribute>` | Text | `eq`, `not_eq`, `cont`, `i_cont`, `not_cont`, `start`, `end`, `in`, `not_in`, `null`, `not_null`, `present`, `blank` |
| `RangeFilters<Attribute, Value?>` | Amounts, counts, dates and times | `eq`, `not_eq`, `lt`, `lteq`, `gt`, `gteq`, `in`, `not_in`, `null`, `not_null` |
| `EnumFilters<Attribute, Value>` | A known set of values that extensions may add to, such as statuses | `eq`, `not_eq`, `in`, `not_in`, `null`, `not_null` |
| `CodeFilters<Attribute, Code>` | A closed code list, such as `CurrencyCode` | `eq`, `not_eq`, `in`, `not_in`, `null`, `not_null` |
| `IdFilters<Attribute>` | Record IDs, such as `prod_86Rf07xd4z` | `eq`, `not_eq`, `in`, `not_in`, `null`, `not_null` |
| `BooleanFilters<Attribute>` | True or false | `eq`, `not_eq`, `in`, `not_in`, `true`, `false`, `null` |
| `Prefixed<Prefix, Filters>` | Filters on an associated record, such as `variants_sku_eq` | — |
| `SortKey<Attribute>` | Sorting: `'name'`, descending `'-name'`, or two fields `'name,-price'` | — |

Amounts in `RangeFilters` are decimal strings, like everywhere else in Spree. `FILTER_PREDICATES` lists the conditions for each kind of value, if you need them at runtime, for example to build a filter editor.

## Compatibility

- ES modules and CommonJS, with TypeScript types included.
- Node.js 18 or later, and every current browser.
- `formatMoney` uses the built-in `Intl.NumberFormat`.

## Links

- [Spree documentation](https://spreecommerce.org/docs)
- [Source code](https://github.com/spree/spree/tree/main/packages/core)
- [Report an issue](https://github.com/spree/spree/issues)

## License

MIT
