FactoryBot.define do
  factory :fulfillment, aliases: [:shipment], class: Spree::Fulfillment do
    tracking { 'U10000' }
    cost     { 100.00 }
    status   { 'pending' }
    order
    stock_location

    after(:create) do |fulfillment, _evalulator|
      fulfillment.add_delivery_method(create(:delivery_method), true)
      fulfillment.order.line_items.map do |line_item|
        fulfillment.fulfillment_items.create(
          order_id: fulfillment.order_id,
          variant_id: line_item.variant_id,
          line_item_id: line_item.id,
          quantity: line_item.quantity
        )
      end
    end
  end
end
