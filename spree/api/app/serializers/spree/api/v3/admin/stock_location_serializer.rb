module Spree
  module Api
    module V3
      module Admin
        class StockLocationSerializer < V3::StockLocationSerializer
          typelize seller_id: [:string, nullable: true], seller_name: [:string, nullable: true],
                   active: :boolean, default: :boolean, backorderable_default: :boolean,
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

          # Whose shelf this is — nil for the marketplace's own. On a
          # marketplace the operator's list holds both, and without this the
          # two are indistinguishable. The name rides along so the list can
          # show it without expanding; the full profile is `?expand=seller`.
          attribute :seller_id do |stock_location|
            stock_location.seller&.prefixed_id
          end

          attribute :seller_name do |stock_location|
            stock_location.seller&.name
          end

          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') }
        end
      end
    end
  end
end
