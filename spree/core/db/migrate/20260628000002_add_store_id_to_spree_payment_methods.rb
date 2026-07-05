class AddStoreIdToSpreePaymentMethods < ActiveRecord::Migration[7.2]
  # NOTE: After running this migration, existing payment methods have
  # +store_id IS NULL+ and are invisible to +PaymentMethod.for_store+. Run the
  # backfill immediately to copy ownership from the legacy
  # +spree_payment_methods_stores+ join table:
  #
  #   bundle exec rake spree:upgrade:populate_single_store_associations
  def change
    add_reference :spree_payment_methods, :store, null: true, if_not_exists: true
  end
end
