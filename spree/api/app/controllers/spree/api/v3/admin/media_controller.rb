module Spree
  module Api
    module V3
      module Admin
        class MediaController < ResourceController
          scoped_resource :products

          # The media file, a URL to fetch one from, and the library row to copy
          # are transport, not attributes (+media_attributes+ drops them).
          request_params :media do
            external_references
            include_fields Spree::Api::V3::MediaRequestSchema
            string :attachment, description: 'The file itself, sent as multipart form data. JSON clients upload first and send `signed_id`.'
            string :url, description: 'Fetch an image from this URL, in the background. Images only: an external video uses `external_video_url`.'
            string :signed_id, description: 'A `signed_id` from `files.upload()` for the media file itself.'
            id :source_media_id,
               description: 'Place a file that is already in the library. The new row shares the source file rather than copying it, and takes its own alt, position and variant links from here.'
            id :variant_ids, array: true,
                             description: 'Variants to link this product-level media to. Variants of other products are dropped.'
          end

          def create
            # An external video has no file, so it takes the plain create path
            # even though a URL is present — `url` means "fetch this image from
            # here" and only applies to image rows.
            if permitted_params[:source_media_id].present?
              create_from_library
            elsif permitted_params[:url].present? && !external_video_request?
              create_from_url
            elsif permitted_params[:signed_id].present?
              create_from_signed_id
            else
              authorize_and_create(build_resource)
            end
          end

          protected

          # `url` and `signed_id` say how to *fetch* the bytes; neither is an
          # attribute on the row. A re-synced asset already has its file, so
          # the replay only carries them as leftovers from the create shape.
          def normalize_upsert_params!
            params.delete(:url)
            params.delete(:signed_id)
          end

          def model_class
            Spree::Media
          end

          def serializer_class
            Spree.api.admin_media_serializer
          end

          # A product's gallery is part of the product: authorizing the product
          # here is the whole check, and the per-record hook stays a no-op so a
          # media key is never required to manage a product's own pictures.
          # The media keys govern the library.
          def authorize_resource!(resource = @resource, action = action_name.to_sym); end

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
            @parent.send(parent_association).build(media_attributes)
          end

          # Everything the client sent minus the transport keys — a direct file,
          # the URL to fetch one from, and the library row to copy are ways of
          # getting at a file, not attributes of the row. Leaving `attachment`
          # in let a request carrying it alongside `source_media_id` overwrite
          # the shared blob with an upload, defeating the reuse.
          def media_attributes
            permitted_params.except(:attachment, :url, :signed_id, :source_media_id)
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end

          def external_video_request?
            permitted_params[:media_type] == 'external_video'
          end

          def create_from_url
            url = permitted_params[:url]
            position = permitted_params[:position]

            # The job runs later, so the identities the connector sent ride
            # along and are written on the media once it exists. All of them:
            # a DAM and a PIM may both name the same asset.
            references = external_reference_params.map { |entry| entry.transform_keys(&:to_s) }
            references = references.presence

            Spree::Images::SaveFromUrlJob.perform_later(
              @parent.id,
              @parent.class.name,
              url,
              references,
              position
            )

            head :accepted
          end

          # Places a file already in the library onto this product or variant.
          # The copy shares the source's blob, so nothing is uploaded and no
          # rendition is regenerated; it gets its own alt, position and variant
          # links from there on.
          #
          # The source is fetched through the store's own library, so a media id
          # belonging to another store reads as a 404 rather than copying a
          # file across the tenancy boundary.
          def create_from_library
            source = current_store.media.find_by_prefix_id!(permitted_params[:source_media_id])

            @resource = source.duplicate_for(@parent)
            # Anything the client sent alongside the source wins over what was
            # copied, so a merchant can place a file and correct its alt text
            # for the new context in one request.
            @resource.assign_attributes(media_attributes)

            authorize_and_create(@resource)
          end

          def create_from_signed_id
            @resource = build_resource
            @resource.attachment.attach(permitted_params[:signed_id])

            authorize_and_create(@resource)
          end

          # The common tail of every create branch. Wraps the base class's
          # save_and_render with the per-record authorization the branches
          # share, since each builds its record a different way.
          def authorize_and_create(media)
            authorize_resource!(media, :create)
            save_and_render(media, status: :created)
          end
        end
      end
    end
  end
end
