module Spree
  module Api
    module V3
      module Seller
        module Products
          # Removing a file from one of this seller's own products.
          #
          # Delete only: the gallery's other writes ride the product update,
          # which never removes a file it was not sent — so a form holding
          # stale state cannot wipe a seller's pictures. Like the rest of a
          # gallery edit, removal does not send an approved listing back to
          # review.
          class MediaController < Seller::ResourceController
            scoped_resource :products

            protected

            def model_class
              Spree::Media
            end

            # Rooted in the seller's own catalog, so another seller's product
            # is a 404. Changing a product's gallery is a change to the
            # product, so it needs `:update` on it.
            def set_parent
              @parent = current_seller.products.find_by_prefix_id!(params[:product_id])
              authorize_parent!(@parent)
            end

            # The product's gallery, plus any file still pinned to its default
            # variant from before galleries moved to the product — the same
            # rows the product shows.
            def scope
              Spree::Media.where(viewable: @parent).or(
                Spree::Media.where(viewable_type: 'Spree::Variant', viewable_id: @parent.default_variant&.id)
              )
            end

            # The product's own authorization above is the check.
            def authorize_resource!(resource = @resource, action = action_name.to_sym); end
          end
        end
      end
    end
  end
end
