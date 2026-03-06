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
              Spree.api.image_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end

            def parent_association
              :assets
            end

            def build_resource
              asset_type = permitted_params[:type] || 'Spree::Image'
              asset_class = asset_type.safe_constantize

              unless asset_class && asset_class <= Spree::Asset
                raise ArgumentError, "Invalid asset type: #{asset_type}"
              end

              # Build through parent association, then set the correct STI type
              asset = @parent.assets.build(permitted_params.except(:type, :variant_ids))
              asset.type = asset_class.name
              asset.viewable = @parent.master if asset.viewable.nil?

              asset
            end

            def permitted_params
              params.permit(:alt, :position, :attachment, :type, :viewable_type, :viewable_id, variant_ids: [])
            end
          end
        end
      end
    end
  end
end
