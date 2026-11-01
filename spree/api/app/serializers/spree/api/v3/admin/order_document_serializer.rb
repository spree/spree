module Spree
  module Api
    module V3
      module Admin
        class OrderDocumentSerializer < V3::OrderDocumentSerializer
          typelize customer_visible: :boolean,
                   order_id: :string,
                   uploaded_by_id: [:string, nullable: true],
                   uploaded_by_type: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          attributes :customer_visible, :metadata, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :order, :uploaded_by

          attribute :uploaded_by_type do |document|
            Spree::Base.polymorphic_api_type(document.uploaded_by_type) if document.uploaded_by_type
          end

          attribute :download_url do |document|
            next nil unless document.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_admin_order_document_path(
              order_id: document.order.prefixed_id, id: document.prefixed_id
            )
          end
        end
      end
    end
  end
end
