FactoryBot.define do
  factory :cart, class: Spree::Cart do
    store { Spree::Store.find_by(default: true) || association(:store) }
    currency { 'USD' }

    factory :cart_with_line_items do
      transient do
        line_items_count { 1 }
        line_items_price { BigDecimal(10) }
      end

      after(:create) do |cart, evaluator|
        create_list(:line_item, evaluator.line_items_count, cart: cart, order: nil, price: evaluator.line_items_price)
        cart.line_items.reload
        cart.recalculate_totals!
      end

      # Mid-checkout: addresses set and delivery proposals built against a
      # real shipping method — the factory replacement for
      # OrderWalkthrough.up_to(:payment).
      factory :cart_ready_for_delivery do
        email { 'buyer@example.com' }

        transient do
          shipping_cost { 10 }
        end

        after(:create) do |cart, evaluator|
          create(:check_payment_method, store: cart.store) if Spree::PaymentMethod.none?

          country = Spree::Country.by_iso('US')

          if Spree::DeliveryMethod.none?
            create(:shipping_method).tap do |delivery_method|
              delivery_method.calculator.preferred_amount = evaluator.shipping_cost
              delivery_method.calculator.preferred_currency = cart.store.default_currency
              delivery_method.calculator.save!
            end
          end

          cart.update!(
            ship_address: create(:address, country: country, state: country.states.first),
            bill_address: create(:address, country: country, state: country.states.first)
          )
          cart.rebuild_fulfillments!
          cart.set_fulfillments_cost
          cart.recalculate_totals!
        end

        # Payment-covered and completable — the factory replacement for a
        # walkthrough cart with a full check payment.
        factory :cart_ready_to_complete do
          after(:create) do |cart|
            create(:payment, cart: cart, order: nil, payment_method: Spree::PaymentMethod.first, amount: cart.reload.total)
          end
        end
      end
    end
  end
end
