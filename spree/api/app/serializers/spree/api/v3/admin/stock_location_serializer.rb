module Spree
  module Api
    module V3
      module Admin
        class StockLocationSerializer < V3::StockLocationSerializer
          typelize active: :boolean, default: :boolean, backorderable_default: :boolean,
                   propagate_all_variants: :boolean, pickup_enabled: :boolean,
                   admin_name: [:string, nullable: true],
                   address2: [:string, nullable: true], state_name: [:string, nullable: true],
                   phone: [:string, nullable: true], company: [:string, nullable: true],
                   kind: :string, pickup_stock_policy: :string,
                   pickup_ready_in_minutes: [:number, nullable: true],
                   pickup_instructions: [:string, nullable: true]

          attributes :admin_name, :address2, :state_name, :phone, :company,
                     :active, :default, :backorderable_default, :propagate_all_variants,
                     :kind, :pickup_enabled, :pickup_stock_policy,
                     :pickup_ready_in_minutes, :pickup_instructions,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
