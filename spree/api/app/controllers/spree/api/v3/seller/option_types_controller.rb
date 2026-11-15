module Spree
  module Api
    module V3
      module Seller
        # The option types (and their values) a seller may build variants from.
        #
        # Read only. A seller picks from the marketplace's vocabulary; adding a
        # type or a value to it is the operator's. Products do not need a
        # product type to use these: a variant names an existing type and value
        # directly, and the products endpoint refuses a name that is not here.
        #
        # Option types belong to the store rather than to a seller, so this is
        # rooted in the seller's store, like the product types endpoint.
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
            Spree::OptionType.for_store(current_store).includes(:option_values).reorder(:position)
          end
        end
      end
    end
  end
end
