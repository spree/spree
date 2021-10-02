module Spree
  module Api
    module V2
      module Platform
        class TaxRateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :zone
          belongs_to :tax_category
        end
      end
    end
  end
end
