// Configuration
export { initSpreeNext, getClient } from './config';
export type { SpreeNextConfig, SpreeNextOptions } from './types';

// Data reads (plain async functions — wrap with "use cache" in your app)
export { listProducts, getProduct, getProductFilters } from './data/products';
export { listCategories, getCategory, listCategoryProducts } from './data/categories';
export { listCountries, getCountry } from './data/countries';
export { listCurrencies } from './data/currencies';
export { listLocales } from './data/locales';
export { listMarkets, getMarket, resolveMarket, listMarketCountries, getMarketCountry } from './data/markets';

// Server actions (mutations + auth-dependent reads)
export {
  getCart,
  getOrCreateCart,
  addItem,
  updateItem,
  removeItem,
  clearCart,
  associateCart,
  updateCart,
  getShipments,
  selectShippingRate,
  applyCoupon,
  removeCoupon,
  complete,
} from './actions/cart';

export {
  login,
  register,
  logout,
  getCustomer,
  updateCustomer,
} from './actions/auth';

export {
  listAddresses,
  getAddress,
  createAddress,
  updateAddress,
  deleteAddress,
} from './actions/addresses';

export { listOrders, getOrder } from './actions/orders';
export { setLocale } from './actions/locale';
export { listCreditCards, deleteCreditCard } from './actions/credit-cards';
export { listGiftCards, getGiftCard } from './actions/gift-cards';

export { createPayment } from './actions/payments';

export {
  createPaymentSession,
  getPaymentSession,
  updatePaymentSession,
  completePaymentSession,
} from './actions/payment-sessions';

export {
  createPaymentSetupSession,
  getPaymentSetupSession,
  completePaymentSetupSession,
} from './actions/payment-setup-sessions';

// Re-export commonly used SDK types for convenience
export type {
  Cart,
  Product,
  Order,
  LineItem,
  Variant,
  Category,
  Country,
  Currency,
  Locale,
  Market,
  Address,
  Customer,
  CreditCard,
  DigitalLink,
  GiftCard,
  Shipment,
  ShippingRate,
  Payment,
  PaymentMethod,
  PaymentSession,
  PaymentSetupSession,
  Image,
  OptionType,
  OptionValue,
  Price,
  CartPromotion,
  OrderPromotion,
  PaginatedResponse,
  AddressParams,
  CreateCartParams,
  LineItemInput,
  UpdateCartParams,
  ProductFiltersResponse,
  CreatePaymentParams,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
  CreatePaymentSetupSessionParams,
  CompletePaymentSetupSessionParams,
  SpreeError,
} from '@spree/sdk';
