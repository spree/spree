# @spree/core

Code every [Spree Commerce](https://spreecommerce.org) client shares, whatever it runs on: the country, currency, locale and unit code lists, exact money arithmetic, and the filter vocabulary the APIs accept. It has no dependencies and makes no network calls, so it works in browsers, Node, edge runtimes and React Native.

The Store, Admin and Seller SDKs already export the code lists and money helpers. Install this package directly when you need these helpers without an API client.

## Installation

```bash
npm install @spree/core
```

## Code lists

The same closed lists the Spree API accepts and returns, each code documented with its English name:

```typescript
import { CountryCode, CurrencyCode, LocaleCode, WeightUnit, DimensionUnit } from '@spree/core';

CurrencyCode.USD; // 'USD'
LocaleCode.pt_BR; // 'pt-BR'
Object.values(WeightUnit); // ['g', 'kg', 'lb', 'oz']
```

## Money

Spree sends amounts as decimal strings (`"1234.56"`), never as numbers, so no amount loses a cent to floating point. These helpers work on those strings directly:

```typescript
import { sumMoney, multiplyMoney, compareMoney, formatMoney, decimalPlaces } from '@spree/core';

sumMoney(['19.99', '5.01'], 'USD'); // '25.00'
multiplyMoney('9.99', 3, 'USD'); // '29.97'
compareMoney('10.00', '9.99'); // 1
decimalPlaces('JPY'); // 0
formatMoney('1234.5', 'EUR', 'de-DE'); // '1.234,50 €'
```

## Filters

The types describing the filters a list endpoint accepts (`name_cont`, `price_gteq`, `status_in`, …), for building typed queries of your own. The SDKs use them to type every list method's parameters.

## License

MIT
