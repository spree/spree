module Spree
  module Api
    module V2
      module Platform
        class TaxCategorySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :tax_rates, serializer: Spree::Api::Dependencies.platform_tax_rate_serializer.constantize
        end
      end
    end
  end
end
