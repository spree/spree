module SpreePaypalCheckout
  # The PayPal order for a cart, built with the SDK's request models. One
  # purchase unit carries the amount, the shipping address and, when they
  # reconcile exactly to that amount, the items and their breakdown: PayPal
  # refuses an order whose breakdown does not add up, and 6.0 carts carry fees,
  # line discounts, included tax and store credit a breakdown may not express.
  class OrderPresenter
    include PaypalServerSdk

    ITEM_NAME_MAX_LENGTH = 127
    ITEM_SKU_MAX_LENGTH = 127

    # @param order [Spree::Cart, Spree::Order]
    # @param amount [BigDecimal] what the session charges
    # @param intent [String] CheckoutPaymentIntent::CAPTURE or ::AUTHORIZE
    def initialize(order:, amount:, intent:)
      @order = order
      @amount = amount
      @intent = intent
    end

    # @return [PaypalServerSdk::OrderRequest]
    def order_request
      OrderRequest.new(
        intent: intent,
        purchase_units: [purchase_unit],
        application_context: OrderApplicationContext.new(
          brand_name: order.store.name.to_s.first(127),
          shipping_preference: shipping_details ? OrderApplicationContextShippingPreference::SET_PROVIDED_ADDRESS : OrderApplicationContextShippingPreference::NO_SHIPPING
        )
      )
    end

    # @return [PaypalServerSdk::PurchaseUnitRequest]
    def purchase_unit
      items = paypal_items
      breakdown = items && amount_breakdown

      # Every SDK model has its own "not sent" sentinel, so absent fields are
      # left out of the arguments instead.
      PurchaseUnitRequest.new(**{
        amount: AmountWithBreakdown.new(**{
          currency_code: currency,
          value: Amounts.to_paypal(amount, currency),
          breakdown: breakdown
        }.compact),
        items: (items if breakdown),
        custom_id: order.prefixed_id,
        shipping: shipping_details
      }.compact)
    end

    private

    attr_reader :order, :amount, :intent

    def currency
      order.currency.upcase
    end

    # nil when the parts do not add up to the amount charged, or any of them
    # cannot be written in PayPal's precision.
    def amount_breakdown
      item_total = line_items.sum { |line_item| line_item.price * line_item.quantity }
      shipping = order.delivery_total
      tax_total = order.additional_tax_total
      handling = order.fee_total
      discount = -order.discount_total + order.total_applied_store_credit

      parts = [item_total, shipping, tax_total, handling, discount]
      return if parts.any?(&:negative?)
      return if item_total != order.item_total
      return if item_total + shipping + tax_total + handling - discount != amount

      AmountBreakdown.new(
        item_total: money(item_total),
        shipping: money(shipping),
        tax_total: money(tax_total),
        handling: money(handling),
        discount: money(discount)
      )
    rescue Amounts::UnsupportedAmount
      nil
    end

    # nil when a unit price cannot be written in PayPal's precision, such as a
    # price quoted below the minor unit.
    def paypal_items
      line_items.map do |line_item|
        ItemRequest.new(**{
          name: line_item.name.to_s.first(ITEM_NAME_MAX_LENGTH),
          unit_amount: money(line_item.price),
          quantity: line_item.quantity.to_s,
          # PayPal refuses a longer SKU, and a cut one could name another product.
          sku: (line_item.sku.presence if line_item.sku.to_s.length <= ITEM_SKU_MAX_LENGTH),
          category: line_item.digital? ? ItemCategory::DIGITAL_GOODS : ItemCategory::PHYSICAL_GOODS
        }.compact)
      end
    rescue Amounts::UnsupportedAmount
      nil
    end

    # Only an address the buyer cannot change in PayPal's window, and none at
    # all when nothing ships, so PayPal never collects one Spree did not price.
    def shipping_details
      return @shipping_details if defined?(@shipping_details)

      address = order.ship_address
      @shipping_details = if address.present? && address.address1.present? && order.shipping_address_required?
                            ShippingDetails.new(
                              name: ShippingName.new(full_name: address.full_name.to_s.first(300)),
                              address: Address.new(**{
                                address_line_1: address.address1,
                                address_line_2: address.address2.presence,
                                admin_area_2: address.city.presence,
                                admin_area_1: address.state_code.presence,
                                postal_code: address.postal_code.presence,
                                country_code: address.country_code
                              }.compact)
                            )
                          end
    end

    def line_items
      # Delivery profiles decide whether a line is digital.
      @line_items ||= order.line_items.includes(variant: [:delivery_profile, { product: :delivery_profile }]).to_a
    end

    def money(value)
      Amounts.to_paypal_money(value, currency)
    end
  end
end
