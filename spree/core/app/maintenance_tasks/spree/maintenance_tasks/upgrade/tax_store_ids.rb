module Spree
  module MaintenanceTasks
    module Upgrade
      # Binds tax categories and rates that predate store ownership to the
      # default store, soft-deleted rows included — a deleted rate is still
      # referenced by the tax lines of orders that were placed under it.
      class TaxStoreIds < Spree::MaintenanceTask
        description 'maintenance_tasks.upgrade.tax_store_ids.description'
        no_collection

        precondition('No default store found — create a store first.') { Spree::Store.default.present? }

        def process
          store = Spree::Store.default

          tally(:tax_categories,
                Spree::TaxCategory.with_deleted.where(store_id: nil).update_all(store_id: store.id))
          tally(:tax_rates, Spree::TaxRate.with_deleted.where(store_id: nil).update_all(store_id: store.id))
        end
      end
    end
  end
end
