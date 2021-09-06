module Spree
  module Api
    module V2
      module Storefront
        class WishedVariantsController < ::Spree::Api::V2::ResourceController
          def create
            spree_authorize! :create, Spree::WishedVariant
            spree_authorize! :update, wishlist

            wished_variant = Spree::WishedVariant.new(wished_variant_attributes)

            if wishlist.include? params[:wished_variant][:variant_id]
              wished_variant = wishlist.wished_variants.detect { |wp| wp.variant_id == params[:wished_variant][:variant_id].to_i }
            else
              wished_variant.wishlist = wishlist
              wished_variant.save
            end

            wishlist.reload
            if wished_variant.persisted?
              render_serialized_payload { serialize_resource(wished_variant) }
            else
              render_error_payload(wished_variant.errors.full_messages.to_sentence)
            end
          end

          def update
            spree_authorize! :update, resource
            resource.update(wished_variant_attributes)

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
            @resource ||= wishlist.wished_variants.find(params[:id])
          end

          def wishlist
            @wishlist ||= current_store.wishlists.find_by!(token: params[:wishlist_id])
          end

          def wished_variant_attributes
            params.require(:wished_variant).permit(permitted_wished_variant_attributes)
          end

          def resource_serializer
            ::Spree::V2::Storefront::WishedVariantSerializer
          end
        end
      end
    end
  end
end
