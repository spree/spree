module Spree
  module Api
    module V3
      module Admin
        class AssetsController < ResourceController
          def create
            if permitted_params[:url].present?
              create_from_url
            else
              @resource = build_resource
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
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

            @parent = if params[:variant_id].present?
                        @product.variants_including_master.find_by_prefix_id!(params[:variant_id])
                      else
                        @product.master
                      end
          end

          def parent_association
            :images
          end

          ALLOWED_ASSET_TYPES = -> { [Spree::Asset, *Spree::Asset.descendants].map(&:name).to_set.freeze }

          def build_resource
            asset_type = permitted_params[:type] || 'Spree::Image'

            unless ALLOWED_ASSET_TYPES.call.include?(asset_type)
              raise ArgumentError, "Invalid asset type: #{asset_type}"
            end

            asset = @parent.images.build(permitted_params.except(:type, :url))
            asset.type = asset_type

            asset
          end

          def permitted_params
            params.permit(*Spree::PermittedAttributes.asset_attributes)
          end

          def create_from_url
            authorize!(:create, Spree::Asset)

            url = permitted_params[:url]
            position = permitted_params[:position]

            Spree::Images::SaveFromUrlJob.perform_later(
              @parent.id,
              @parent.class.name,
              url,
              nil,
              position
            )

            head :accepted
          end
        end
      end
    end
  end
end
