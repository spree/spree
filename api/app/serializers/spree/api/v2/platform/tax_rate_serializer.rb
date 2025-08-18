module Spree
  module Api
    module V2
      module Platform
        class TaxRateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :zone, serializer: Spree::Api::Dependencies.platform_zone_serializer.constantize
          belongs_to :tax_category, serializer: Spree::Api::Dependencies.platform_tax_category_serializer.constantize
        end
      end
    end
  end
end
