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
          # Blobs are minted on private storage, because attaching a signed id
          # never moves a blob between services and a purchase order carries the
          # buyer's prices, terms and internal cost codes.
          class PoDocumentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include ActiveStorage::SetCurrent

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/po_document
            #
            # Exchanges blob metadata for an upload URL. The returned signed id
            # is then sent back as `po_document` on a cart update, which is what
            # actually attaches it.
            #
            # The declared size and type are checked here, before any URL is
            # minted. A guest cart is self-service, so without this an
            # anonymous caller could mint uploads for arbitrarily large files
            # and fill the merchant's bucket — the attachment's own validation
            # only runs once the bytes are already stored. It is a gate on the
            # cheap lie, not a substitute: the attach-time check still reads
            # the stored object, which is what catches an under-declared size.
            def create
              return render_po_document_invalid unless acceptable_upload?

              blob = ActiveStorage::Blob.create_before_direct_upload!(
                service_name: Spree.private_storage_service_name, **blob_params
              )

              render json: {
                direct_upload: {
                  url: blob.service_url_for_direct_upload,
                  headers: blob.service_headers_for_direct_upload
                },
                signed_id: blob.signed_id
              }, status: :created
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

            def blob_params
              params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type).to_h.symbolize_keys
            end

            def acceptable_upload?
              declared_size = Integer(blob_params[:byte_size].to_s, exception: false)

              declared_size&.positive? &&
                declared_size <= Spree::Purchase::PurchaseOrder::MAX_PO_DOCUMENT_SIZE &&
                Spree::Purchase::PurchaseOrder::PO_DOCUMENT_CONTENT_TYPES.include?(blob_params[:content_type])
            end

            def render_po_document_invalid
              render_error(
                code: ERROR_CODES[:parameter_invalid],
                message: Spree.t(
                  :po_document_invalid,
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
