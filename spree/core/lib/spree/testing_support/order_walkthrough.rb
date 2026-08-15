# Cart-first checkout walkthrough. `up_to(step)` returns a Spree::Cart with
# every step BEFORE the given one satisfied (matching the legacy contract
# where `up_to(:delivery)` had completed the address step). `up_to(:complete)`
# runs the real completion pipeline and returns the resulting Spree::Order.
# @deprecated Removed in Spree 6.1 — build checkout state with the factories
#   instead: create(:cart_ready_for_delivery) (address + delivery proposals),
#   create(:cart_ready_to_complete) (payment-covered), or
#   create(:completed_order_with_totals) for a placed order.
class OrderWalkthrough
  def self.up_to(state, store = nil)
    Spree::Deprecation.warn('OrderWalkthrough is deprecated and will be removed in Spree 6.1. Use the cart factories instead: :cart_ready_for_delivery, :cart_ready_to_complete, or :completed_order_with_totals.')
    store ||= Spree::Store.default

    # A payment method must exist for checkout to proceed
    unless Spree::PaymentMethod.exists?
      FactoryBot.create(:check_payment_method)
    end

    country = FactoryBot.create(:country)
    country.states << FactoryBot.create(:state, country: country)

    # A delivery method must exist for rates to be displayed on checkout page
    unless Spree::DeliveryMethod.exists?
      FactoryBot.create(:shipping_method).tap do |delivery_method|
        delivery_method.calculator.preferred_amount = 10
        delivery_method.calculator.preferred_currency = store.default_currency
        delivery_method.calculator.save
      end
    end

    cart = store.carts.create!(currency: store.default_currency, email: 'spree@example.com')
    add_line_item!(cart)

    end_state_position = states.index(state.to_sym)
    states[0...end_state_position].each do |step|
      send(step, cart)
    end

    return complete_cart!(cart) if state.to_sym == :complete

    cart.recalculate_totals!
    cart
  end

  def self.add_line_item!(cart)
    FactoryBot.create(:line_item, cart: cart, order: nil)
    cart.reload
  end

  def self.address(cart)
    country = Spree::Country.by_iso('US')
    cart.bill_address = FactoryBot.create(:address, country: country)
    cart.ship_address = FactoryBot.create(:address, country: country)
    cart.save!
    cart.rebuild_fulfillments!
    cart.set_fulfillments_cost
  end

  def self.delivery(cart)
    # Rates were proposed with the address; keep the selected defaults.
    cart.recalculate_totals!
  end

  def self.payment(cart)
    FactoryBot.create :payment,
      cart: cart,
      order: nil,
      payment_method: Spree::PaymentMethod.first,
      amount: cart.reload.total
  end

  def self.complete_cart!(cart)
    result = Spree::Carts::Complete.call(cart: cart)
    raise "OrderWalkthrough completion failed: #{result.error&.value.inspect}" if result.failure?

    result.value
  end

  def self.states
    [:address, :delivery, :payment, :complete]
  end
end
