module Spree
  module Api
    module V3
      module Orders
        # Paperwork on an order that is not an invoice
        # (docs/plans/6.1-b2b-order-documents.md). Shared by the operator's and
        # the seller's branches; `@parent` is the order, already fetched
        # through the caller's own scope.
        module OrderDocumentActions
          extend ActiveSupport::Concern

          included do
            include Spree::Api::V3::StreamsPrivateFile

            before_action :set_resource, only: [:show, :update, :destroy, :download]

            request_params :order_document do |body|
              body.attribute :label, :string, required: true, on: :create, example: 'Signed purchase order'
              body.attribute :customer_visible, :boolean,
                description: "Whether the buyer sees it on their order. Off unless set; the buyer's own uploads are always visible to them."
              body.attribute :file_signed_id, :string, required: true, on: :create,
                description: "A `signed_id` from `files.upload()` with `visibility: 'private'`. PDF, image, office document or CSV."
              body.attribute :metadata, :hash
            end
          end

          # GET .../documents/:id/download
          def download
            stream_private_file(@resource.file)
          end

          protected

          def model_class
            Spree::OrderDocument
          end

          def parent_association
            :order_documents
          end

          def collection_includes
            [{ file_attachment: :blob }]
          end

          def read_actions
            %w[index show download]
          end

          def permitted_params
            attributes = params.permit(*declared_permitted_attributes)
            # A file is the document; replacing it is uploading a new one.
            attributes = attributes.except(:file_signed_id) if action_name == 'update'
            attributes
          end

          def build_resource
            super.tap do |document|
              document.store = @parent.store
              document.uploaded_by = current_actor
            end
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action == :download ? :show : action, resource)
          end
        end
      end
    end
  end
end
