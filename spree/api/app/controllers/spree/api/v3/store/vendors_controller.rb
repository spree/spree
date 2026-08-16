module Spree
  module Api
    module V3
      module Store
        # Public seller profiles.
        #
        # Read-only, and scoped to vendors a shopper can actually buy from: one
        # still onboarding, suspended or away has nothing to show a customer,
        # and listing them would advertise sellers whose products cannot be
        # bought.
        class VendorsController < ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::Vendor
          end

          def serializer_class
            Spree.api.vendor_serializer
          end

          def scope
            super.sellable
          end

          # By slug or prefixed ID, so a storefront can route
          # `/vendors/sparks-audio` without holding an id.
          def find_resource
            id = params[:id]

            if id.to_s.start_with?('ven_')
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
