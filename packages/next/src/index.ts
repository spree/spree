// Configuration
export { initSpreeNext, getClient } from './config';
export type { SpreeNextConfig, SpreeNextOptions } from './types';

// Data reads (plain async functions — wrap with "use cache" in your app)
export { listProducts, getProduct, getProductFilters } from './data/products';
export { listTaxons, getTaxon, listTaxonProducts } from './data/taxons';
export { listTaxonomies, getTaxonomy } from './data/taxonomies';
export { getStore } from './data/store';
export { listCountries, getCountry } from './data/countries';
export { listCurrencies } from './data/currencies';
export { listLocales } from './data/locales';

// Server actions (mutations + auth-dependent reads)
export {
  getCart,
  getOrCreateCart,
  addItem,
  updateItem,
  removeItem,
  clearCart,
  associateCart,
} from './actions/cart';

export {
  getCheckout,
  updateAddresses,
  advance,
  next,
  getShipments,
  selectShippingRate,
  applyCoupon,
  removeCoupon,
  complete,
} from './actions/checkout';

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
export { listCreditCards, deleteCreditCard } from './actions/credit-cards';
export { listGiftCards, getGiftCard } from './actions/gift-cards';

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
  StoreProduct,
  StoreOrder,
  StoreLineItem,
  StoreVariant,
  StoreTaxon,
  StoreTaxonomy,
  StoreCountry,
  StoreCurrency,
  StoreLocale,
  StoreStore,
  StoreAddress,
  StoreCustomer,
  StoreCreditCard,
  StoreDigitalLink,
  StoreGiftCard,
  StoreShipment,
  StoreShippingRate,
  StorePayment,
  StorePaymentMethod,
  StorePaymentSession,
  StorePaymentSetupSession,
  StoreImage,
  StoreOptionType,
  StoreOptionValue,
  StorePrice,
  StoreOrderPromotion,
  PaginatedResponse,
  AddressParams,
  ProductFiltersResponse,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
  CreatePaymentSetupSessionParams,
  CompletePaymentSetupSessionParams,
  SpreeError,
} from '@spree/sdk';
