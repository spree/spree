module Spree
  module Api
    module V3
      module Seller
        # The seller's own tax registrations — the numbers the marketplace's
        # commission invoice is made out to, and what makes EU reverse charge
        # on that fee possible.
        #
        # A collection rather than a single field, for the same reason a
        # company's is: a business trading in more than one regime holds a
        # registration in each, and they are not alternatives. One per kind,
        # which the model enforces.
        #
        # Rooted in `current_seller.tax_identifiers`, so an id belonging to
        # another seller is a 404.
        class TaxIdentifiersController < Seller::ResourceController
          include Spree::Api::V3::TaxIdentifierValidation

          # Part of the seller's own identity, like the legal name and billing
          # address the profile carries — not a store-wide setting.
          scoped_resource :seller_profile

          # Re-declaring the filter replaces the inherited options, so the
          # standard actions have to be listed alongside the custom one.
          before_action :set_resource, only: [:show, :update, :destroy, :validate]

          protected

          def model_class
            Spree::TaxIdentifier
          end

          def serializer_class
            Spree.api.seller_tax_identifier_serializer
          end

          def seller_association
            :tax_identifiers
          end

          def permitted_params
            params.permit(:kind, :value)
          end
        end
      end
    end
  end
end
