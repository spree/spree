FactoryBot.define do
  factory :return, class: Spree::Return do
    transient do
      # Number of fulfilled units to return; capped at what the order has.
      line_items_count { 1 }
    end

    association(:order, factory: :shipped_order)
    store { order.store }
    stock_location { order.shipments.first&.stock_location || create(:stock_location) }
    status { Spree::Return.default_status }
    memo { 'Item did not fit' }

    after(:build) do |return_record, evaluator|
      next if return_record.return_line_items.any?

      return_record.order.fulfillment_items.limit(evaluator.line_items_count).each do |fulfillment_item|
        return_record.return_line_items.build(
          fulfillment_item: fulfillment_item,
          line_item: fulfillment_item.line_item,
          variant: fulfillment_item.variant,
          quantity: 1
        )
      end
    end

    factory :approved_return do
      status { 'approved' }
      approved_at { Time.current }
    end

    factory :received_return do
      status { 'received' }
      approved_at { 1.day.ago }
      received_at { Time.current }

      after(:create) do |return_record|
        return_record.return_line_items.each do |line|
          line.update!(received_quantity: line.quantity)
        end
      end
    end
  end

  # A single announced line. Its fulfillment item, line item and variant have to
  # agree with each other, so the caller passes them — usually copied from a
  # sibling line it already holds.
  factory :return_line_item, class: Spree::ReturnLineItem do
    quantity { 1 }
    received_quantity { 0 }
  end
end
