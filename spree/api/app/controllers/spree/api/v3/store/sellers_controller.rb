module Spree
  module Api
    module V3
      module Store
        # Public seller profiles.
        #
        # Read-only, and scoped to sellers a shopper can actually buy from: one
        # still onboarding, suspended or away has nothing to show a customer,
        # and listing them would advertise sellers whose products cannot be
        # bought.
        class SellersController < ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::Seller
          end

          def serializer_class
            Spree.api.seller_serializer
          end

          def scope
            super.sellable
          end

          # By slug or prefixed ID, so a storefront can route
          # `/sellers/sparks-audio` without holding an id.
          def find_resource
            id = params[:id]

            if id.to_s.start_with?('sel_')
              scope.find_by_prefix_id!(id)
            else
              scope.find_by!(slug: id)
            end
          end
        end
      end
    end
  end
end
