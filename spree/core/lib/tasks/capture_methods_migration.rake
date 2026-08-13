# frozen_string_literal: true

# 5.6 → 6.0 conversion of the per-payment-method auto_capture boolean onto the
# capture_method vocabulary (docs/plans/6.0-store-scoped-configuration.md).
# Idempotent — it only writes rows whose capture_method is still empty, so a
# second run finds nothing to do and an interrupted run resumes for free.
namespace :spree do
  desc 'Convert payment method auto_capture booleans into capture_method values'
  task migrate_capture_methods: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i
    say = ->(message) { puts message }

    payment_methods = Spree::PaymentMethod.unscoped.where(capture_method: nil)

    # A method that captured on authorization charges at checkout. One that did
    # not only recorded "not at checkout" — the old column could not say
    # whether dispatch or staff was meant to take the money, and the store's
    # own setting is what decided. Leaving those rows empty is what makes them
    # keep inheriting it, so only the true case is written here.
    count = payment_methods.where(auto_capture: true).
            in_batches(of: batch_size).
            update_all(capture_method: 'checkout')
    say.call "spree_payment_methods.capture_method: #{count} rows auto_capture → checkout"

    remaining = Spree::PaymentMethod.unscoped.where(capture_method: nil, auto_capture: false).count
    say.call "spree_payment_methods.capture_method: #{remaining} rows left inheriting the store setting"

    say.call 'migrate_capture_methods done.'
  end
end
