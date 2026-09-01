module Spree
  module Api
    module V3
      module Seller
        # The marketplace's delivery profiles — what kind of goods a product
        # is (parcel, digital, pallet), which decides how it can be shipped.
        #
        # Read only: a seller assigns a profile to their product and never
        # defines one, since the profile is the vocabulary the marketplace's
        # zones and methods hang off
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        #
        # Gated on `read_products` rather than the operator's `settings` key,
        # which a seller must never hold: this list exists for the product
        # form's picker, so a key that may read products may read the
        # vocabulary that form fills in.
        class DeliveryProfilesController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::DeliveryProfile
          end

          def serializer_class
            Spree.api.seller_delivery_profile_serializer
          end

          def scope
            current_store.delivery_profiles
          end
        end
      end
    end
  end
end
