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
        #
        # It backs the delivery-method form's picker too, so `delivery_methods`
        # opens it as well — a member granted only that key would otherwise
        # load the page and find an empty "kind of goods" list with no way to
        # create a method.
        class DeliveryProfilesController < Seller::ResourceController
          scoped_resource :products

          protected

          # Either key reads this vocabulary. Answers whichever the caller
          # actually holds so the gate passes for both surfaces; the declared
          # resource stands as the default, which keeps the fail-closed
          # behaviour when neither is held.
          def scoped_resource_name
            reads_through_delivery_methods? ? :delivery_methods : super
          end

          # Checked against whichever principal is on the request — a secret
          # key answers by its scopes, a signed-in member by their role's keys.
          def reads_through_delivery_methods?
            return false if holds_key?('read_products')

            holds_key?('read_delivery_methods')
          end

          def holds_key?(key)
            return current_api_key.has_scope?(key) if current_api_key.present?

            ability = current_ability
            ability.respond_to?(:permission_keys) && ability.permission_keys.include?(key)
          end

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
