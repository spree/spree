module Spree
  module Api
    module V3
      module Seller
        # An option type as a seller picks it: a name, a label and, on request,
        # the values to choose from. Read only; the marketplace defines the
        # vocabulary.
        class OptionTypeSerializer < V3::OptionTypeSerializer
          many :option_values,
               resource: proc { Spree.api.seller_option_value_serializer },
               if: proc { expand?('option_values') }
        end
      end
    end
  end
end
