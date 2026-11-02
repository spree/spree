module Spree
  module Api
    module V3
      module Store
        module Orders
          # Documents on the buyer's order: those staff made visible, and
          # the buyer's own uploads, which are always visible to them.
          class DocumentsController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerOrderParent
            include Spree::Api::V3::StreamsPrivateFile

            before_action :set_resource, only: [:download]

            request_params 'CreateOrderDocumentUploadParams', action: :upload do |body|
              body.attribute :filename, :string, required: true
              body.attribute :content_type, :string, required: true
              body.attribute :byte_size, :integer, required: true
              body.attribute :checksum, :string, required: true,
                description: 'Base64-encoded MD5 digest of the file; the storage service checks the bytes against it.'
            end

            request_params 'CreateOrderDocumentParams', action: :create do |body|
              body.attribute :label, :string, required: true, example: 'Purchase order 4471'
              body.attribute :file_signed_id, :string, required: true,
                description: "A `signed_id` from `files.upload()` with `visibility: 'private'`. PDF, image, office document or CSV."
            end

            # POST /api/v3/store/orders/:order_id/documents/upload
            #
            # Prepares a private upload for the buyer's document. Nested under
            # the order rather than offered as a general store endpoint: a
            # publishable key is public, and reaching this action means holding
            # the order. The declared size and type are checked before any URL
            # is minted; attaching re-checks the stored bytes.
            def upload
              file_upload = Spree::FileUpload.for_private_document(
                Spree::OrderDocument, :file,
                store: current_store, **params.permit(*declared_permitted_attributes).to_h.symbolize_keys
              )

              if file_upload.save
                render json: Spree.api.file_upload_serializer.new(file_upload, params: serializer_params).to_h, status: :created
              else
                render_validation_error(file_upload.errors)
              end
            end

            protected

            def model_class
              Spree::OrderDocument
            end

            def serializer_class
              Spree.api.order_document_serializer
            end

            # The buyer's own uploads are always visible: the model refuses
            # hiding them, so this one scope covers both.
            def scope
              @parent.order_documents.customer_visible
            end

            def collection_includes
              [{ file_attachment: :blob }]
            end

            def parent_association
              :order_documents
            end

            # Only what the storefront request declares: attributes an extension
            # adds to the model are for staff, not for whoever holds the
            # publishable key.
            def permitted_params
              params.permit(*declared_permitted_attributes)
            end

            # What the buyer adds is theirs, and so always shown to them.
            def build_resource
              super.tap do |document|
                document.assign_attributes(store: @parent.store, customer_visible: true, uploaded_by_customer: true,
                                           uploaded_by: try_spree_current_user)
              end
            end

            def read_actions
              %w[index download]
            end
          end
        end
      end
    end
  end
end
