module Spree
  module Api
    module V2
      module Platform
        class StockLocationSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :name
          belongs_to :country
        end
      end
    end
  end
end
