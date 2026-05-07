module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::Export}.
        #
        # Extends the public {Spree::Api::V3::ExportSerializer} with the fields
        # the SPA needs to drive the export-and-download flow:
        #
        # * `done` flips to `true` once {Spree::Exports::GenerateJob} attaches
        #   the CSV. The SPA polls `GET /admin/exports/:id` on this flag.
        # * `download_url` points at our own
        #   `GET /api/v3/admin/exports/:id/download` action, which authorizes
        #   the request and 302s to a freshly-signed ActiveStorage URL. This
        #   matches the legacy `Spree::Admin::ExportsController#show` flow and
        #   keeps URL-signing concerns out of serialization.
        # * `filename` and `byte_size` let the UI show "products-store-…csv
        #   (1.2 MB)" without a second request.
        class ExportSerializer < V3::ExportSerializer
          typelize done: :boolean,
                   download_url: [:string, nullable: true],
                   filename: [:string, nullable: true],
                   byte_size: [:number, nullable: true]

          attribute(:done) { |export| export.done? }

          attribute :filename do |export|
            export.attachment.filename.to_s if export.done?
          end

          attribute :byte_size do |export|
            export.attachment.byte_size if export.done?
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
