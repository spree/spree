module Spree
  # A confidential file served only through an authenticated download action:
  # private storage, a `<slot>_signed_id` write name, an allowlist checked
  # against the bytes, and a size cap measured on disk.
  #
  #   has_private_document :file, content_types: %w[application/pdf], max_size: 10.megabytes
  #
  # The cap is measured on the stored object as well as on the blob's declared
  # `byte_size`, because a direct upload declares its size before sending a
  # byte and the download action buffers what it serves.
  module PrivateDocument
    extend ActiveSupport::Concern

    included do
      # Each slot's accepted types and size cap, so an upload can be refused
      # before a byte is sent (see Spree::FileUpload.for_private_document).
      class_attribute :private_document_limits, instance_writer: false, default: {}
    end

    class_methods do
      # @param slot [Symbol] the `has_one_attached` name
      # @param content_types [Array<String>] accepted types, decided from the bytes
      # @param max_size [Integer] bytes
      # @param required [Boolean] whether the record is invalid without a file
      # @return [void]
      def has_private_document(slot, content_types:, max_size:, required: false)
        has_one_attached slot, service: Spree.private_storage_service_name
        signed_id_attachments slot
        self.private_document_limits = private_document_limits.merge(slot => { content_types: content_types, max_size: max_size })

        validates slot, attached: true if required
        validates slot, size: { less_than_or_equal_to: max_size }, if: -> { public_send(slot).attached? }
        validates_with Spree::AttachmentContentTypeValidator,
                       attributes: [slot], in: content_types,
                       if: -> { public_send(slot).attached? }
        # Only when a file arrives: the check downloads up to the cap, which an
        # edit to the record's other fields has no reason to pay for.
        validate(if: -> { attachment_changes[slot.to_s].present? }) do
          private_document_within_size_on_disk(slot, max_size)
        end
      end
    end

    private

    def private_document_within_size_on_disk(slot, max_size)
      blob = public_send(slot).blob
      return if blob.nil? || !blob.service.exist?(blob.key)

      stored_size = 0
      blob.service.download(blob.key) do |chunk|
        stored_size += chunk.bytesize
        break if stored_size > max_size
      end
      return if stored_size <= max_size

      errors.add(
        slot, :private_document_too_large,
        message: I18n.t('spree.private_document_too_large',
                        size: ActiveSupport::NumberHelper.number_to_human_size(max_size))
      )
    end
  end
end
