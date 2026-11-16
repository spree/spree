module Spree
  module Api
    module V3
      module Seller
        class StockLocationSerializer < V3::StockLocationSerializer
          # The Store API keeps these deprecated names until 6.5.
          %i[country_iso state_abbr].each { |key| _attributes.delete(key) }

          typelize address2: [:string, nullable: true], state_name: [:string, nullable: true],
                   phone: [:string, nullable: true], company: [:string, nullable: true],
                   admin_name: [:string, nullable: true],
                   active: :boolean, default: :boolean, kind: [:string, enum: Spree::StockLocation::KINDS, enum_type_name: 'StockLocationKind'],
                   backorderable_default: :boolean, propagate_all_variants: :boolean,
                   pickup_enabled: :boolean, returns_enabled: :boolean,
                   pickup_stock_policy: [:string, enum: Spree::StockLocation::PICKUP_STOCK_POLICIES, enum_type_name: 'PickupStockPolicy']

          attributes :admin_name, :address2, :state_name, :phone, :company, :active, :default, :kind,
                     :backorderable_default, :propagate_all_variants,
                     :pickup_enabled, :pickup_stock_policy, :returns_enabled,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
