module Spree
  module Api
    module V3
      module Store
        module Carts
          # The buyer's purchase-order document — the signed paperwork the
          # `po_number` on the cart refers to
          # (docs/plans/6.0-b2b-customer-po-numbers.md).
          #
          # Presigning is nested under the cart rather than offered as a general
          # store upload endpoint: a publishable key is public, so an
          # unconditional presigner would let anyone holding one mint blobs in
          # the merchant's bucket. Reaching this action means holding the cart.
          #
          # Files are minted on private storage, because attaching a signed id
          # never moves a blob between services and a purchase order carries the
          # buyer's prices, terms and internal cost codes.
          class PoDocumentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include ActiveStorage::SetCurrent

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/po_document
            #
            # Takes the same flat request as the Admin API's `POST /files` and
            # answers with the same shape. The returned signed id is then sent
            # back as `po_document_signed_id` on a cart update, which is what
            # actually attaches it.
            #
            # The declared size and type are checked here, before any URL is
            # minted. A guest cart is self-service, so without this an
            # anonymous caller could mint uploads for arbitrarily large files
            # and fill the merchant's bucket — the attachment's own validation
            # only runs once the bytes are already stored. It is a gate on the
            # cheap lie, not a substitute: the attach-time check still reads
            # the stored object, which is what catches an under-declared size.
            # Bytes in the request itself are not accepted here: a publishable
            # key is public.
            def create
              file_upload = Spree::FileUpload.new(
                store: current_store,
                visibility: 'private',
                max_byte_size: Spree::Purchase::PurchaseOrder::MAX_PO_DOCUMENT_SIZE,
                allowed_content_types: Spree::Purchase::PurchaseOrder::PO_DOCUMENT_CONTENT_TYPES,
                **params.permit(:filename, :content_type, :byte_size, :checksum).to_h.symbolize_keys
              )

              return render_po_document_invalid unless file_upload.save

              render json: Spree.api.file_upload_serializer.new(file_upload, params: serializer_params).to_h, status: :created
            end

            # GET /api/v3/store/carts/:cart_id/po_document
            #
            # Streamed rather than redirected to storage, so the document stays
            # reachable only by whoever holds the cart.
            def show
              return head :not_found unless @cart.po_document.attached?

              send_data(
                @cart.po_document.download,
                filename: @cart.po_document.filename.to_s,
                type: @cart.po_document.content_type || 'application/octet-stream',
                disposition: 'attachment'
              )
            end

            # DELETE /api/v3/store/carts/:cart_id/po_document
            #
            # Detaches rather than purges: completion attaches the same blob to
            # the order, so destroying the bytes here would take the placed
            # order's copy with them.
            def destroy
              return head :not_found unless @cart.po_document.attached?

              @cart.po_document.detach
              head :no_content
            end

            private

            def render_po_document_invalid
              render_error(
                code: ERROR_CODES[:parameter_invalid],
                message: I18n.t(
                  'spree.po_document_invalid',
                  size: ActiveSupport::NumberHelper.number_to_human_size(
                    Spree::Purchase::PurchaseOrder::MAX_PO_DOCUMENT_SIZE
                  )
                ),
                status: :unprocessable_content
              )
            end
          end
        end
      end
    end
  end
end
