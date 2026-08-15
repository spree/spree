module Spree
  module MaintenanceTasks
    module Upgrade
      # Binds delivery methods and stock locations that predate store ownership
      # to the default store.
      #
      # Stock locations are bound including soft-deleted rows: a deleted
      # location still owns stock movements an order references, so leaving it
      # store-less would strand that history.
      class DeliveryAndStockStoreIds < Spree::MaintenanceTask
        description 'maintenance_tasks.upgrade.delivery_and_stock_store_ids.description'
        no_collection

        precondition('No default store found — create a store first.') { Spree::Store.default.present? }

        def process
          store = Spree::Store.default

          tally(:delivery_methods, Spree::DeliveryMethod.where(store_id: nil).update_all(store_id: store.id))
          tally(:stock_locations,
                Spree::StockLocation.with_deleted.where(store_id: nil).update_all(store_id: store.id))
        end
      end
    end
  end
end
