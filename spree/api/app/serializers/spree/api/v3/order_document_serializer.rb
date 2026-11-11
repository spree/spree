module Spree
  module Api
    module V3
      # A document on the buyer's order: one staff made visible, or the
      # buyer's own upload.
      class OrderDocumentSerializer < BaseSerializer
        typelize label: :string,
                 uploaded_by_customer: :boolean,
                 download_url: [:string, nullable: true]

        attributes :label

        attribute(:uploaded_by_customer, &:uploaded_by_customer?)

        private_file_attributes :file

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
