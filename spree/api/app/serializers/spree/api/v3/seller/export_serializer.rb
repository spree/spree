module Spree
  module Api
    module V3
      module Seller
        # Seller API serializer for {Spree::Export}.
        #
        # Mirrors the operator's, pointed at the seller branch's own download
        # endpoint: the bytes are streamed by that action rather than handed
        # over as a pre-signed ActiveStorage URL, so the seller's own session
        # is what authorizes every download.
        #
        # `user_id` is inherited but names the seller's own staff member, and
        # the marketplace's `results_url` is not exposed — a seller reads the
        # file, not the operator's bookkeeping about it.
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

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_export_path(
              id: export.prefixed_id
            )
          end
        end
      end
    end
  end
end
