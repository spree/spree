module Spree
  module Api
    module V3
      module Admin
        class MediaSerializer < V3::MediaSerializer
          include Concerns::ExternalReferencesAttribute

          # Both are null for a library file that has not been placed yet.
          typelize viewable_type: [:string, nullable: true],
                   viewable_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   download_url: [:string, nullable: true],
                   embed_url: [:string, nullable: true],
                   filename: [:string, nullable: true],
                   content_type: [:string, nullable: true],
                   byte_size: [:number, nullable: true],
                   signed_id: [:string, nullable: true],
                   attached: :boolean

          attributes created_at: :iso8601, updated_at: :iso8601

          # Whether this file is placed on a product, or sitting in the library
          # waiting to be used.
          attribute :attached do |asset|
            asset.viewable_id.present?
          end

          # File facts the library grid and detail panel show. Read from the
          # blob rather than the legacy attachment_* columns, which are only
          # populated on pre-6.0 rows.
          attribute :filename do |asset|
            asset.attachment_blob&.filename&.to_s
          end

          attribute :content_type do |asset|
            asset.attachment_blob&.content_type
          end

          attribute :byte_size do |asset|
            asset.attachment_blob&.byte_size
          end

          # The rendition rich text embeds point at: bounded to a sane width,
          # never cropped, so a size chart or diagram keeps its proportions.
          attribute :embed_url do |asset|
            next nil unless asset.image? && asset.attachment.attached?

            Rails.application.routes.url_helpers.cdn_image_url(asset.attachment.variant(:embed))
          end

          # The file's own signed id, which is what a plain attachment field
          # (a category image, a store logo) accepts on write. Handing it over
          # lets those fields adopt a library file, sharing the blob instead of
          # uploading a second copy — the same economics as placing media on a
          # product, through endpoints that need no change.
          attribute :signed_id do |asset|
            asset.attachment_blob&.signed_id
          end

          attribute :viewable_id do |asset|
            asset.viewable&.prefixed_id
          end

          # Forces Content-Disposition: attachment so admins downloading from
          # cloud storage (S3) get a save-as instead of an inline view. Mirrors
          # the host resolution from the `:cdn_image` direct route since
          # rails_blob_url itself doesn't fall back to Spree.cdn_host or the
          # current store's domain.
          attribute :download_url do |asset|
            next nil unless asset.attachment&.attached?

            host = Spree.cdn_host.presence ||
                   Rails.application.routes.default_url_options[:host] ||
                   Spree::Store.current&.url_or_custom_domain
            helpers = Rails.application.routes.url_helpers

            if host.present?
              helpers.rails_blob_url(asset.attachment.blob, disposition: 'attachment', host: host)
            else
              helpers.rails_blob_path(asset.attachment.blob, disposition: 'attachment')
            end
          end

          attributes :metadata

          # `"product"` / `"variant"`, not the polymorphic class name.
          attribute :viewable_type do |asset|
            Spree::Base.polymorphic_api_type(asset.viewable_type)
          end
        end
      end
    end
  end
end
