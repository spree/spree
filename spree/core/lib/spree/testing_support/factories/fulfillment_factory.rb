FactoryBot.define do
  factory :fulfillment, aliases: [:shipment], class: Spree::Fulfillment do
    transient do
      # Tracking is a Spree::Delivery since 6.0; the number given here becomes
      # the fulfillment's primary delivery once it is created. nil for a
      # parcel that has no tracking yet.
      tracking { 'U10000' }
    end

    cost     { 100.00 }
    status   { 'unfulfilled' }
    order    { cart.present? ? nil : association(:order) }
    stock_location

    after(:create) do |fulfillment, evaluator|
      fulfillment.add_delivery_method(create(:delivery_method), true)
      (fulfillment.order || fulfillment.cart).line_items.map do |line_item|
        fulfillment.fulfillment_items.create(
          order_id: fulfillment.order_id,
          variant_id: line_item.variant_id,
          line_item_id: line_item.id,
          quantity: line_item.quantity
        )
      end

      if evaluator.tracking.present?
        create(:delivery, owner: fulfillment, store: fulfillment.store, tracking_number: evaluator.tracking)
        fulfillment.deliveries.reset
      end
    end
  end
end
