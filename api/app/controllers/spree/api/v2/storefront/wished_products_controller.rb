module Spree
  module Api
    module V2
      module Storefront
        class WishedProductsController < ::Spree::Api::V2::BaseController

          def create
            spree_authorize! :create, Spree::WishedProduct
            spree_authorize! :update, wishlist

            wished_product = Spree::WishedProduct.new(wished_product_attributes)

            if wishlist.include? params[:wished_product][:variant_id]
              wished_product = wishlist.wished_products.detect {|wp| wp.variant_id == params[:wished_product][:variant_id].to_i }
            else
              wished_product.wishlist = wishlist
              wished_product.save
            end

            wishlist.reload
            if wished_product.persisted?
              render_serialized_payload { serialize_resource(wished_product) }
            else
              render_error_payload(wished_product.errors.full_messages.to_sentence)
            end
          end

          def update
            spree_authorize! :update, resource
            resource.update(wished_product_attributes)

            if resource.errors.empty?
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def destroy
            spree_authorize! :destroy, resource
            if resource.destroy
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload('Something went wrong')
            end
          end

          private

          def resource
            @resource ||= wishlist.wished_products.find(params[:id])
          end

          def wishlist
            @wishlist ||= Spree::Wishlist.find_by!(access_hash: params[:wishlist_id])
          end

          def wished_product_attributes
            params.require(:wished_product).permit(:variant_id, :quantity, :remark)
          end

          def resource_serializer
            ::Spree::V2::Storefront::WishedProductSerializer
          end
        end
      end
    end
  end
end
