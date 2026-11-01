module Spree
  module Api
    module V3
      module Store
        module Orders
          # Documents on the buyer's order: those staff made visible, and
          # the buyer's own uploads, which are always visible to them.
          class DocumentsController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerOrderParent
            include ActiveStorage::SetCurrent

            before_action :set_resource, only: [:download]

            request_params :order_document, action: :create do |body|
              body.attribute :label, :string, required: true, example: 'Purchase order 4471'
              body.attribute :file_signed_id, :string, required: true,
                description: "A `signed_id` from `files.upload()` with `visibility: 'private'`. PDF, image, office document or CSV."
            end

            def create
              document = @parent.order_documents.new(
                store: @parent.store,
                label: params[:label],
                file_signed_id: params[:file_signed_id],
                customer_visible: true,
                uploaded_by: try_spree_current_user
              )

              if document.save
                render json: serialize_resource(document), status: :created
              else
                render_validation_error(document.errors)
              end
            end

            # GET /api/v3/store/orders/:order_id/documents/:id/download
            def download
              send_data(
                @resource.file.download,
                filename: @resource.file.filename.to_s,
                type: @resource.file.content_type || 'application/octet-stream',
                disposition: 'attachment'
              )
            end

            protected

            def model_class
              Spree::OrderDocument
            end

            def serializer_class
              Spree.api.order_document_serializer
            end

            def scope
              @parent.order_documents.customer_visible
            end

            def collection_includes
              [{ file_attachment: :blob }]
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
