namespace :spree do
  desc <<~DESC
    Assigns the default store to delivery methods and stock locations that
    predate their store binding (Spree 6.0). Idempotent — rows that already
    carry a store_id are skipped. Every unassigned record goes to the
    default store; additional stores manage their own records afterwards.
  DESC
  task backfill_delivery_and_stock_store_ids: :environment do
    store = Spree::Store.default
    abort 'No default store found — create a store first.' if store.nil?

    methods = Spree::DeliveryMethod.where(store_id: nil).update_all(store_id: store.id)
    locations = Spree::StockLocation.with_deleted.where(store_id: nil).update_all(store_id: store.id)

    puts "  Assigned #{methods} delivery methods and #{locations} stock locations to store #{store.name} (#{store.id})."
  end

  desc <<~DESC
    Assigns the default store to tax rates and tax categories that predate
    their store binding (Spree 6.0). Idempotent — rows that already carry a
    store_id are skipped. Soft-deleted rows are bound too, so restoring one
    later still yields a valid record.
  DESC
  task backfill_tax_store_ids: :environment do
    store = Spree::Store.default
    abort 'No default store found — create a store first.' if store.nil?

    categories = Spree::TaxCategory.with_deleted.where(store_id: nil).update_all(store_id: store.id)
    rates = Spree::TaxRate.with_deleted.where(store_id: nil).update_all(store_id: store.id)

    puts "  Assigned #{categories} tax categories and #{rates} tax rates to store #{store.name} (#{store.id})."
  end
end
