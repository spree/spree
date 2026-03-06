module Spree
  module Api
    module V3
      module Admin
        module Products
          class AssetsController < ResourceController
            def create
              @resource = build_resource
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def model_class
              Spree::Asset
            end

            def serializer_class
              Spree.api.admin_asset_serializer
            end

            def set_parent
              @product = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @product)
              @parent = @product.master
            end

            def parent_association
              :images
            end

            def build_resource
              asset_type = permitted_params[:type] || 'Spree::Image'
              asset_class = asset_type.safe_constantize

              unless asset_class && asset_class <= Spree::Asset
                raise ArgumentError, "Invalid asset type: #{asset_type}"
              end

              asset = @parent.images.build(permitted_params.except(:type, :variant_ids))
              asset.type = asset_class.name

              asset
            end

            def permitted_params
              params.permit(*Spree::PermittedAttributes.asset_attributes, variant_ids: [])
            end
          end
        end
      end
    end
  end
end
