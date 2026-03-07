module Spree
  module Api
    module V3
      module Admin
        class TaxCategorySerializer < V3::TaxCategorySerializer
          typelize is_default: :boolean, tax_code: [:string, nullable: true]

          attributes :is_default, :tax_code,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
