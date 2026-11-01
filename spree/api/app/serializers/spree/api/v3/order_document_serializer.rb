module Spree
  module Api
    module V3
      # A document on the buyer's order: one staff made visible, or the
      # buyer's own upload.
      class OrderDocumentSerializer < BaseSerializer
        typelize label: :string,
                 file_filename: [:string, nullable: true],
                 file_byte_size: ['number | null'],
                 file_content_type: [:string, nullable: true],
                 uploaded_by_customer: :boolean,
                 download_url: [:string, nullable: true]

        attributes :label

        attribute(:uploaded_by_customer, &:uploaded_by_customer?)

        attribute :file_filename do |document|
          document.file.blob&.filename&.to_s if document.file.attached?
        end

        attribute :file_byte_size do |document|
          document.file.blob&.byte_size if document.file.attached?
        end

        attribute :file_content_type do |document|
          document.file.blob&.content_type if document.file.attached?
        end

        attribute :download_url do |document|
          next nil unless document.file.attached?

          Spree::Core::Engine.routes.url_helpers.download_api_v3_store_order_document_path(
            order_id: document.order.prefixed_id, id: document.prefixed_id
          )
        end
      end
    end
  end
end
