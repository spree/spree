module Spree
  module MaintenanceTasks
    module Upgrade
      # Gives every pre-6.0 stock movement a kind and a concrete cause key
      # derived from its polymorphic originator, and reconciles the
      # fulfillments left open by the conversion.
      class StockMovementsToTypedRows < RakeStep
        description 'maintenance_tasks.upgrade.stock_movements_to_typed_rows.description'

        runs_rake_task 'spree:migrate_stock_movements_to_typed_rows'
      end
    end
  end
end
