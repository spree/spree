module Spree
  module Purchase
    # The buyer's own purchase-order reference, shared by Spree::Cart and
    # Spree::Order. Not to be confused with Spree::PurchaseOrder, which is the
    # merchant's procurement order to a supplier — the opposite direction
    # (docs/plans/6.0-b2b-customer-po-numbers.md).
    #
    # A corporate buyer reconciles the order, the invoice and the payment
    # against this number years later, so it is a plain indexed column rather
    # than metadata, and it carries onto the order at completion. The optional
    # document is the PO itself — the signed paperwork the number refers to.
    module PurchaseOrder
      extend ActiveSupport::Concern

      # A scanned or exported purchase order, not an archive. Bounded because
      # the download action reads the whole blob into memory to serve it.
      MAX_PO_DOCUMENT_SIZE = 10.megabytes

      # What a purchase order plausibly arrives as: an export from the buyer's
      # procurement system, a scan, or a photo of one. Matches the list the
      # seller document requirement accepts — the same kinds of paperwork.
      PO_DOCUMENT_CONTENT_TYPES = %w[
        application/pdf
        image/jpeg
        image/png
        image/heic
        image/webp
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
      ].freeze

      included do
        normalizes :po_number, with: ->(value) { value.strip.presence }

        # Private storage: a purchase order carries a buyer's prices, terms and
        # internal cost codes, and is served only through an authenticated
        # download action.
        has_one_attached :po_document, service: Spree.private_storage_service_name

        # Buyers are the lower-trust writers here — the storefront uploads this
        # — so the bytes decide what the file is, not the header the uploader
        # sent. Without spoofing_protection a script named `po.pdf` passes.
        validates :po_document,
                  content_type: { in: PO_DOCUMENT_CONTENT_TYPES, spoofing_protection: true },
                  size: { less_than_or_equal_to: MAX_PO_DOCUMENT_SIZE },
                  if: -> { po_document.attached? }

        validate :po_document_within_size_on_disk, if: -> { po_document.attached? }
      end

      # Whether the buyer's own procurement process demands a PO reference on
      # this purchase. Read through the resolved company, so a buyer who has
      # not yet said which node they are buying for is asked only once their
      # membership is unambiguous.
      #
      # @return [Boolean]
      def po_number_required?
        resolved_company&.po_number_required? || false
      end

      private

      # The size validation above reads the blob's recorded `byte_size`, which
      # a direct upload declares before sending a single byte. A caller who
      # under-declares it would otherwise slip a file of any size past both
      # that check and the presign gate, and the download action buffers what
      # it serves. So the stored object is measured, in chunks rather than by
      # loading it, and only far enough to know it is over the cap.
      def po_document_within_size_on_disk
        blob = po_document.blob
        return if blob.nil?
        return unless blob.service.exist?(blob.key)

        stored_size = 0
        blob.service.download(blob.key) do |chunk|
          stored_size += chunk.bytesize
          break if stored_size > MAX_PO_DOCUMENT_SIZE
        end
        return if stored_size <= MAX_PO_DOCUMENT_SIZE

        errors.add(
          :po_document,
          Spree.t(
            :po_document_too_large,
            size: ActiveSupport::NumberHelper.number_to_human_size(MAX_PO_DOCUMENT_SIZE)
          )
        )
      end
    end
  end
end
