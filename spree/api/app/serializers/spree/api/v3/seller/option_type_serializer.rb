module Spree
  module Api
    module V3
      module Seller
        # An option type as a seller builds variants from it: its name and,
        # when expanded, the values a variant may take.
        #
        # The store shape plus its values, and nothing the operator keeps to
        # maintain the vocabulary — no `metadata`, `filterable` or timestamps.
        class OptionTypeSerializer < V3::OptionTypeSerializer
          many :option_values,
               resource: proc { Spree.api.option_value_serializer },
               if: proc { expand?('option_values') }
        end
      end
    end
  end
end
