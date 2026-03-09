module Spree
  module Api
    module V3
      module Admin
        class TaxCategorySerializer < V3::BaseSerializer
          typelize name: :string, tax_code: [:string, nullable: true],
                   is_default: :boolean

          attributes :name, :tax_code, :is_default,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
