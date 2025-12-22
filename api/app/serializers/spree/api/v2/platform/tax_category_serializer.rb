module Spree
  module Api
    module V2
      module Platform
        class TaxCategorySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :tax_rates, serializer: Spree.api.platform_tax_rate_serializer
        end
      end
    end
  end
end
