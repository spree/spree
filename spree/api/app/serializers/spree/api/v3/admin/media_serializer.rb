module Spree
  module Api
    module V3
      module Admin
        class MediaSerializer < V3::MediaSerializer
          typelize viewable_type: :string, viewable_id: :string,
                   metadata: 'Record<string, unknown>',
                   download_url: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

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

          attributes :metadata, :viewable_type
        end
      end
    end
  end
end
