module Spree
  module MaintenanceTasks
    module Upgrade
      # Binds the return and refund reasons that predate store ownership to the
      # default store. Reasons are store-scoped in 6.0; rows created before that
      # carry no store and would be invisible to every store's admin.
      class ReasonStoreIds < Spree::MaintenanceTask
        description 'maintenance_tasks.upgrade.reason_store_ids.description'
        no_collection

        precondition('No default store found — create a store first.') { Spree::Store.default.present? }

        def process
          store = Spree::Store.default

          tally(:return_reasons, Spree::ReturnReason.where(store_id: nil).update_all(store_id: store.id))
          tally(:refund_reasons, Spree::RefundReason.where(store_id: nil).update_all(store_id: store.id))
        end
      end
    end
  end
end
