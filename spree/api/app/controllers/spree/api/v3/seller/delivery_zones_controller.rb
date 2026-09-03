module Spree
  module Api
    module V3
      module Seller
        # The marketplace's delivery zones — where its methods may ship to.
        #
        # Read only: a seller narrows their own method to one of these and
        # never draws one, because where the marketplace ships is its own
        # decision (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        #
        # Filtered by profile through the usual Ransack parameters, so the
        # panel asks for the zones under the profile a method belongs to.
        class DeliveryZonesController < Seller::ResourceController
          scoped_resource :delivery_methods

          protected

          def model_class
            Spree::DeliveryZone
          end

          def serializer_class
            Spree.api.seller_delivery_zone_serializer
          end

          # `delivery_profile_id` is an explicit filter rather than a Ransack
          # predicate: a zone only means something under its profile, so the
          # picker asks for one profile's zones and an id from another store
          # is a 404 rather than an empty list.
          def scope
            zones = current_store.delivery_zones.includes(:delivery_profile)
            return zones if params[:delivery_profile_id].blank?

            profile = current_store.delivery_profiles.find_by_prefix_id!(params[:delivery_profile_id])
            zones.where(delivery_profile_id: profile.id)
          end
        end
      end
    end
  end
end
