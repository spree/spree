FactoryBot.define do
  factory :order, class: Spree::Order do
    user
    bill_address
    completed_at { nil }
    email        { user&.email }
    currency     { 'USD' }

    transient do
      line_items_price { BigDecimal(10) }
      attach_to_default_store { true }
    end

    before(:create) do |order|
      unless order.store.present?
        default_store = Spree::Store.default.persisted? ? Spree::Store.default : nil
        store = default_store || create(:store)

        order.store = store
      end
    end

    factory :order_with_totals do
      after(:create) do |order, evaluator|
        create(:line_item, order: order, price: evaluator.line_items_price)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :order_with_line_item_quantity do
      transient do
        line_items_quantity { 1 }
      end

      after(:create) do |order, evaluator|
        create(:line_item, order: order, price: evaluator.line_items_price, quantity: evaluator.line_items_quantity)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :order_with_line_items do
      bill_address
      ship_address

      transient do
        line_items_count       { 1 }
        without_line_items     { false }
        shipment_cost          { 100 }
        shipping_method_filter { Spree::ShippingMethod::DISPLAY_ON_FRONT_END }
        variants               { [] }
      end

      after(:create) do |order, evaluator|
        if evaluator.variants.empty? && !evaluator.without_line_items
          create_list(:line_item, evaluator.line_items_count, order: order, price: evaluator.line_items_price)
          order.line_items.reload
        end

        if evaluator.variants.any?
          evaluator.variants.each { |variant| create(:line_item, order: order, product: variant.product, variant: variant, price: evaluator.line_items_price) }
          order.line_items.reload
        end

        stock_location = order.line_items&.first&.variant&.stock_items&.first&.stock_location || create(:stock_location)
        create(:shipment, order: order, cost: evaluator.shipment_cost, stock_location: stock_location)
        order.shipments.reload

        order.update_with_updater!
      end

      factory :completed_order_with_totals do
        state { 'complete' }

        after(:create) do |order, evaluator|
          order.refresh_shipment_rates(evaluator.shipping_method_filter)
          order.update_column(:completed_at, order.completed_at || Time.current)
        end

        factory :completed_order_with_pending_payment do
          after(:create) do |order|
            create(:payment, amount: order.total, order: order)
          end
        end

        factory :completed_order_with_store_credit_payment do
          after(:create) do |order|
            store_credit = create(:store_credit, amount: order.total, store: order.store, user: order.user)
            payment_method = create(:store_credit_payment_method, stores: [order.store])

            create(:store_credit_payment, amount: order.total, order: order, source: store_credit, payment_method: payment_method)
          end
        end

        factory :order_ready_to_ship do
          payment_state  { 'paid' }
          shipment_state { 'ready' }

          transient do
            with_payment { true }
          end

          after(:create) do |order, evaluator|
            create(:payment, amount: order.total, order: order, state: 'completed') if evaluator.with_payment

            order.shipments.each do |shipment|
              shipment.inventory_units.update_all state: 'on_hand'
              shipment.update_column('state', 'ready')
            end
            order.reload
          end

          factory :shipped_order do
            shipment_state { 'shipped' }

            after(:create) do |order|
              order.shipments.each do |shipment|
                shipment.inventory_units.update_all state: 'shipped'
                shipment.update_columns(
                  state: 'shipped',
                  tracking: '1234567890'
                )
              end
            end
          end
        end
      end
    end
  end
end
