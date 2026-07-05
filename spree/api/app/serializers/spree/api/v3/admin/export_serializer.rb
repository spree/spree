module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::Export}.
        #
        # `download_url` is the path to our own download endpoint, not a
        # pre-signed ActiveStorage URL — the controller streams bytes inline
        # so the JWT auth flow runs on every download and works through the
        # SPA's `/api/*`-only dev proxy.
        class ExportSerializer < V3::ExportSerializer
          typelize done: :boolean,
                   download_url: [:string, nullable: true],
                   filename: [:string, nullable: true],
                   byte_size: [:number, nullable: true]

          attribute(:done) { |export| export.done? }

          # Safe-nav on `blob` — `attachment.attached?` can stay true while a
          # background job purges the underlying blob (e.g. retention sweeps).
          attribute :filename do |export|
            export.attachment.blob&.filename&.to_s if export.done?
          end

          attribute :byte_size do |export|
            export.attachment.blob&.byte_size if export.done?
          end

          attribute :download_url do |export|
            next nil unless export.done?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_admin_export_path(
              id: export.prefixed_id
            )
          end
        end
      end
    end
  end
end
