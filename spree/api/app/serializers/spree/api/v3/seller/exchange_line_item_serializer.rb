# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of an exchange — what came back and what goes out in its
        # place. Both variants expand through the seller's own serializer.
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          one :original_variant, resource: proc { Spree.api.seller_variant_serializer },
                                 if: proc { expand?('original_variant') }
          one :new_variant, resource: proc { Spree.api.seller_variant_serializer },
                            if: proc { expand?('new_variant') }
        end
      end
    end
  end
end
