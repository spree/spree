import { StoreOrder, StoreShipment, AddressParams } from '@spree/sdk';

/**
 * Get the current checkout order state.
 */
declare function getCheckout(orderId: string): Promise<StoreOrder>;
/**
 * Update shipping and/or billing addresses on the order.
 */
declare function updateAddresses(orderId: string, params: {
    email?: string;
    ship_address?: AddressParams;
    bill_address?: AddressParams;
    ship_address_id?: string;
    bill_address_id?: string;
}): Promise<StoreOrder>;
/**
 * Advance the checkout to the next step.
 */
declare function advance(orderId: string): Promise<StoreOrder>;
/**
 * Move the checkout to the next step (alias for advance).
 */
declare function next(orderId: string): Promise<StoreOrder>;
/**
 * Get shipments for the order (includes available shipping rates).
 */
declare function getShipments(orderId: string): Promise<{
    data: StoreShipment[];
}>;
/**
 * Select a shipping rate for a shipment.
 */
declare function selectShippingRate(orderId: string, shipmentId: string, shippingRateId: string): Promise<StoreShipment>;
/**
 * Apply a coupon code to the order.
 */
declare function applyCoupon(orderId: string, code: string): Promise<StoreOrder>;
/**
 * Remove a coupon/promotion from the order.
 */
declare function removeCoupon(orderId: string, promotionId: string): Promise<StoreOrder>;
/**
 * Complete the checkout and place the order.
 */
declare function complete(orderId: string): Promise<StoreOrder>;

export { advance, applyCoupon, complete, getCheckout, getShipments, next, removeCoupon, selectShippingRate, updateAddresses };
