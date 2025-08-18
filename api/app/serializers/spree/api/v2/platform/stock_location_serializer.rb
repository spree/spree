module Spree
  module Api
    module V2
      module Platform
        class StockLocationSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :name
          belongs_to :country, serializer: Spree::Api::Dependencies.platform_country_serializer.constantize
        end
      end
    end
  end
end
