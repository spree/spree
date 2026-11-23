module Spree
  module Api
    module V3
      module Seller
        # The marketplace's option types (Size, Colour) and their values, for
        # the variants builder on a seller's product form.
        #
        # Read only: a seller builds their variants from the options the
        # operator defines, and never adds a type or a value to that shared
        # vocabulary (docs/plans/6.0-multi-vendor-marketplace.md).
        #
        # Gated on `read_products`, as delivery profiles are, rather than a key
        # of its own: option types and values are resources of the `products`
        # scope on both branches (the operator's endpoint uses it too), and
        # this list exists only for the product form, so a key that may read
        # products may read the vocabulary that form fills in.
        #
        # Option types belong to the store rather than to a seller, so this is
        # not rooted in `current_seller` — the store comes from the seller,
        # which is what keeps it scoped.
        class OptionTypesController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::OptionType
          end

          def serializer_class
            Spree.api.seller_option_type_serializer
          end

          def scope
            model_class.for_store(current_store).preload_associations_lazily.i18n
          end
        end
      end
    end
  end
end
