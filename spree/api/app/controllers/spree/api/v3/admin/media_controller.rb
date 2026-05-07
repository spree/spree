module Spree
  module Api
    module V3
      module Admin
        class MediaController < ResourceController
          scoped_resource :products

          def create
            if permitted_params[:url].present?
              create_from_url
            elsif permitted_params[:signed_id].present?
              create_from_signed_id
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
            Spree.api.admin_media_serializer
          end

          def set_parent
            @product = current_store.products.find_by_prefix_id!(params[:product_id])
            authorize!(:show, @product)

            @parent = if params[:variant_id].present?
                        @product.variants_including_master.find_by_prefix_id!(params[:variant_id])
                      else
                        @product
                      end
          end

          # Variants store assets via the polymorphic `images` association; products own
          # their gallery via `media`. Both resolve to `Spree::Asset` rows with different
          # `viewable_type` values.
          def parent_association
            params[:variant_id].present? ? :images : :media
          end

          # For product-scoped listings we surface BOTH product-level assets and any
          # legacy master-pinned assets, so existing data keeps showing up while
          # merchants migrate. New uploads land on `Spree::Product` (see #set_parent).
          def scope
            return super if params[:variant_id].present?

            Spree::Asset.where(
              viewable_type: 'Spree::Product', viewable_id: @product.id
            ).or(
              Spree::Asset.where(
                viewable_type: 'Spree::Variant', viewable_id: @product.master&.id
              )
            ).order(:position)
          end

          ALLOWED_MEDIA_TYPES = -> { [Spree::Asset, *Spree::Asset.descendants].map(&:name).to_set.freeze }

          def build_resource
            media_type = permitted_params[:type] || 'Spree::Image'

            unless ALLOWED_MEDIA_TYPES.call.include?(media_type)
              raise ArgumentError, "Invalid media type: #{media_type}"
            end

            media = @parent.send(parent_association).build(permitted_params.except(:type, :url, :signed_id))
            media.type = media_type

            media
          end

          def permitted_params
            params.permit(:type, :alt, :position, :attachment, :url, :signed_id, variant_ids: [])
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

          def create_from_signed_id
            @resource = build_resource
            @resource.attachment.attach(permitted_params[:signed_id])
            authorize_resource!(@resource, :create)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end
        end
      end
    end
  end
end
