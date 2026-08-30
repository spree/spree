module Spree
  module Api
    module V3
      module Admin
        # Admin-only: catalogs are merchandising configuration with no
        # storefront surface — buyers see their effects, never the record.
        class CatalogSerializer < V3::BaseSerializer
          typelize name: :string, active: :boolean, position: [:number, nullable: true],
                   price_list_id: [:string, nullable: true],
                   products_count: :number,
                   metadata: 'Record<string, unknown> | null'

          attributes :name, :active, :position, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :price_list_id do |catalog|
            catalog.price_list&.prefixed_id
          end

          attribute :products_count do |catalog|
            catalog.catalog_products.size
          end

          # The owned list rides along so the agreement editor can render its
          # pricing without a second request — the catalog page is where an
          # owned list is edited (docs/plans/6.0-catalog-agreement-rework.md).
          one :price_list,
              resource: proc { Spree.api.admin_price_list_serializer },
              if: proc { expand?('price_list') }

          many :catalog_assignments, key: :assignments,
               resource: proc { Spree.api.admin_catalog_assignment_serializer },
               if: proc { expand?('assignments') }
        end
      end
    end
  end
end
