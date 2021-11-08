module Spree
  module Api
    module V2
      module Platform
        class TaxCategorySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :tax_rates
        end
      end
    end
  end
end
