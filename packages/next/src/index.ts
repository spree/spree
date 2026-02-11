// Configuration
export { initSpreeNext, getClient } from './config';
export type { SpreeNextConfig, SpreeNextOptions } from './types';

// Data reads (plain async functions — wrap with "use cache" in your app)
export { listProducts, getProduct, getProductFilters } from './data/products';
export { listTaxons, getTaxon, listTaxonProducts } from './data/taxons';
export { listTaxonomies, getTaxonomy } from './data/taxonomies';
export { getStore } from './data/store';
export { listCountries, getCountry } from './data/countries';

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

// Re-export commonly used SDK types for convenience
export type {
  StoreProduct,
  StoreOrder,
  StoreLineItem,
  StoreVariant,
  StoreTaxon,
  StoreTaxonomy,
  StoreCountry,
  StoreStore,
  StoreAddress,
  StoreCustomer,
  StoreCreditCard,
  StoreGiftCard,
  StoreShipment,
  StoreShippingRate,
  StorePayment,
  StorePaymentMethod,
  StoreImage,
  StoreOptionType,
  StoreOptionValue,
  StorePrice,
  StoreOrderPromotion,
  PaginatedResponse,
  AddressParams,
  ProductFiltersResponse,
  SpreeError,
} from '@spree/sdk';
