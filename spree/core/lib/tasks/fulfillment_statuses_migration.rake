# frozen_string_literal: true

# 5.6 → 6.0 status remap for the fulfillment lifecycle
# (docs/plans/6.0-fulfillment-and-delivery.md, Phase 7). Batched and
# idempotent — every statement narrows to legacy values only, so a second run
# finds nothing left to do and an interrupted run resumes for free.
namespace :spree do
  desc 'Remap fulfillment statuses onto the unfulfilled/fulfilled/delivered vocabulary'
  task migrate_fulfillment_statuses: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i
    say = ->(message) { puts message }

    fulfillments = Spree::Fulfillment.unscoped

    # pending and ready both described a package still on the shelf. The
    # difference between them was the order's payment state, which is no longer
    # a property of the fulfillment.
    %w(pending ready).each do |legacy|
      count = fulfillments.where(status: legacy).in_batches(of: batch_size).update_all(status: 'unfulfilled')
      say.call "spree_fulfillments.status: #{count} rows #{legacy} → unfulfilled"
    end

    # ready_for_pickup meant "waiting at the counter", which is what fulfilled
    # means for a pickup fulfillment now.
    count = fulfillments.where(status: 'ready_for_pickup').in_batches(of: batch_size).update_all(status: 'fulfilled')
    say.call "spree_fulfillments.status: #{count} rows ready_for_pickup → fulfilled"

    # Under the old machine a pickup fulfillment reached `fulfilled` only when
    # the customer collected it — that is confirmed receipt, so those rows are
    # delivered rather than merely handed over. Shipping fulfillments stay
    # `fulfilled`: whether they arrived was never recorded.
    pickup_method_ids = Spree::DeliveryMethod.
                        select { |delivery_method| delivery_method.provider.class.pickup? }.
                        map(&:id)

    if pickup_method_ids.any?
      pickup_fulfillment_ids = Spree::DeliveryRate.
                               where(selected: true, delivery_method_id: pickup_method_ids).
                               select(:fulfillment_id)

      count = fulfillments.
              where(status: 'fulfilled', id: pickup_fulfillment_ids).
              where(delivered_at: nil).
              in_batches(of: batch_size).
              update_all('status = \'delivered\', delivered_at = fulfilled_at')
      say.call "spree_fulfillments.status: #{count} pickup rows fulfilled → delivered"
    end

    # Order rollups are derived, so they are recomputed rather than mapped —
    # this also picks up the new `delivered` value for orders whose parcels all
    # arrived.
    orders = Spree::Order.where(fulfillment_status: %w(pending ready ready_for_pickup))
    total = orders.count
    orders.find_each { |order| order.update_statuses! }
    say.call "spree_orders.fulfillment_status: #{total} orders recomputed"

    say.call 'migrate_fulfillment_statuses done.'
  end
end
