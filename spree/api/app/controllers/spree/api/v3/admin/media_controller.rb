module Spree
  module Api
    module V3
      module Admin
        class MediaController < ResourceController
          scoped_resource :products

          def create
            # An external video has no file, so it takes the plain create path
            # even though a URL is present — `url` means "fetch this image from
            # here" and only applies to image rows.
            if permitted_params[:url].present? && !external_video_request?
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
            Spree::Media
          end

          def serializer_class
            Spree.api.admin_media_serializer
          end

          def set_parent
            @product = current_store.products.find_by_prefix_id!(params[:product_id])
            authorize!(:update, @product)

            @parent = if params[:variant_id].present?
                        @product.variants.find_by_prefix_id!(params[:variant_id])
                      else
                        @product
                      end
          end

          # Variants store assets via the polymorphic `images` association; products own
          # their gallery via `media`. Both resolve to `Spree::Media` rows with different
          # `viewable_type` values.
          def parent_association
            params[:variant_id].present? ? :images : :media
          end

          # For product-scoped listings we surface BOTH product-level assets and any
          # legacy assets still pinned to the default variant, so existing data keeps
          # showing up while merchants migrate. New uploads land on `Spree::Product`
          # (see #set_parent).
          def scope
            return super if params[:variant_id].present?

            Spree::Media.where(
              viewable_type: 'Spree::Product', viewable_id: @product.id
            ).or(
              Spree::Media.where(
                viewable_type: 'Spree::Variant', viewable_id: @product.default_variant&.id
              )
            ).order(:position)
          end

          def build_resource
            @parent.send(parent_association).build(permitted_params.except(:url, :signed_id))
          end

          # The media file and a URL to fetch one from are transport, not
          # attributes — everything a client can set lives on the model.
          def permitted_params
            params.permit(
              *model_additional_permitted_attributes,
              *Spree::Media::WRITABLE_ATTRIBUTES,
              :attachment, :url, :signed_id,
              variant_ids: []
            )
          end

          def external_video_request?
            permitted_params[:media_type] == 'external_video'
          end

          def create_from_url
            authorize!(:create, Spree::Media)

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
