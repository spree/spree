# frozen_string_literal: true

# 5.6 → 6.0: the tracking number that lived on the fulfillment becomes its
# primary Spree::Delivery (docs/plans/6.0-shipping-labels-and-deliveries.md).
# Idempotent — a fulfillment that already has a delivery for its number is
# skipped, so an interrupted run resumes for free. Labels are not backfilled:
# the provider metadata keys only ever existed on the unreleased 6.0 edge.
namespace :spree do
  desc 'Create a delivery for every fulfillment that carries a 5.6 tracking number'
  task migrate_deliveries: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 1_000).to_i
    say = ->(message) { puts message }

    created = 0
    skipped = 0

    # The column is dropped in 6.1; until then the model reads tracking from
    # the delivery, so the legacy value is read straight off the row.
    fulfillments = Spree::Fulfillment.unscoped.
                   where.not(tracking: [nil, '']).
                   where.not(id: Spree::Delivery.where(owner_type: 'Spree::Fulfillment').select(:owner_id))

    fulfillments.includes(:order, :cart).find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |fulfillment|
        tracking = fulfillment.read_attribute(:tracking).to_s.squish
        if fulfillment.owner&.store.nil?
          skipped += 1
          say.call "  skipped #{fulfillment.number}: its order or cart is gone, so it has no store"
          next
        end

        # A dev database that ran the withdrawn 20260811 carrier migration
        # still has the column; anywhere else it never existed.
        carrier = fulfillment.has_attribute?(:tracking_carrier) ? fulfillment.read_attribute(:tracking_carrier) : nil

        result = Spree.delivery_create_service.call(
          owner: fulfillment, tracking_number: tracking, carrier: carrier
        )

        if result.success?
          created += 1
        else
          skipped += 1
          say.call "  skipped #{fulfillment.number}: #{result.error}"
        end
      end
    end

    say.call "spree_deliveries: #{created} created, #{skipped} skipped"
    say.call 'migrate_deliveries done.'
  end
end
