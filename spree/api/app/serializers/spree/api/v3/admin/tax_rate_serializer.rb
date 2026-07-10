module Spree
  module Api
    module V3
      module Admin
        class TaxRateSerializer < V3::BaseSerializer
          typelize name: :string,
                   amount: :decimal,
                   tax_category_id: :string,
                   zone_id: [:string, nullable: true],
                   included_in_price: :boolean

          attributes :name, :amount, :tax_category_id, :zone_id, :included_in_price,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
