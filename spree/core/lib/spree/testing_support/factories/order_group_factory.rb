FactoryBot.define do
  factory :order_group, class: Spree::OrderGroup do
    store { Spree::Store.default || create(:store) }
    customer
    currency { 'USD' }
    email { customer&.email }

    # A split checkout as it actually leaves completion: each child holding a
    # seller's item and the parcel that ships it. `:with_orders` builds bare
    # orders, which is enough for roll-up arithmetic and not enough for
    # anything that renders the purchase.
    #
    # One stock location per seller by default, so each parcel is quoted on its
    # own delivery method and the group ships in as many parcels as it has
    # children. Pass `shared_stock_location: true` for the marketplace-fulfilled
    # shape instead: every child ships out of one warehouse on one method, which
    # is what a divided parcel looks like after the split clones it.
    trait :with_parcels do
      transient do
        sellers_count { 2 }
        shared_stock_location { false }
      end

      after(:create) do |group, evaluator|
        shared_location = create(:stock_location, name: "Shared #{group.number}") if evaluator.shared_stock_location
        shared_method = create(:delivery_method, name: "Shared #{group.number}") if evaluator.shared_stock_location

        evaluator.sellers_count.times do |index|
          seller = create(:seller, :approved, store: group.store)
          order = create(
            :order_with_line_items,
            store: group.store,
            order_group: group,
            seller: seller,
            number: "#{group.number}-#{index + 1}",
            customer: group.customer,
            currency: group.currency,
            line_items_count: 1
          )
          order.line_items.each { |line_item| line_item.update_columns(seller_id: seller.id) }

          # The order factory already built the parcel; this decides where it
          # ships from and by what, which is what the grouping reads.
          fulfillment = order.fulfillments.first
          fulfillment.update_columns(
            stock_location_id: (shared_location || create(:stock_location, name: "#{seller.name} warehouse")).id
          )
          fulfillment.delivery_rates.destroy_all
          fulfillment.add_delivery_method(shared_method || create(:delivery_method, name: "#{seller.name} delivery"), true)
          order.recalculate_totals!
        end

        group.orders.reload
      end
    end

    trait :with_orders do
      transient do
        sellers_count { 2 }
      end

      after(:create) do |group, evaluator|
        evaluator.sellers_count.times do |index|
          create(
            :order,
            store: group.store,
            order_group: group,
            seller: create(:seller, :approved, store: group.store),
            number: "#{group.number}-#{index + 1}",
            customer: group.customer,
            currency: group.currency
          )
        end
        group.orders.reload
      end
    end
  end
end
