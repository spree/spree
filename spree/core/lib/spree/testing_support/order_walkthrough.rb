# Cart-first checkout walkthrough. `up_to(step)` returns a Spree::Cart with
# every step BEFORE the given one satisfied (matching the legacy contract
# where `up_to(:delivery)` had completed the address step). `up_to(:complete)`
# runs the real completion pipeline and returns the resulting Spree::Order.
class OrderWalkthrough
  def self.up_to(state, store = nil)
    store ||= Spree::Store.default

    # A payment method must exist for checkout to proceed
    unless Spree::PaymentMethod.exists?
      FactoryBot.create(:check_payment_method)
    end

    # Need to create a valid zone too...
    zone = FactoryBot.create(:zone)
    country = FactoryBot.create(:country)
    zone.members << Spree::ZoneMember.create(zoneable: country)
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
    cart.bill_address = FactoryBot.create(:address, country_id: Spree::Zone.global.members.first.zoneable.id)
    cart.ship_address = FactoryBot.create(:address, country_id: Spree::Zone.global.members.first.zoneable.id)
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
