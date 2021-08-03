module Spree
  module Api
    module V2
      module Platform
        class TaxCategorySerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          # TODO: add tax_rates
        end
      end
    end
  end
end
