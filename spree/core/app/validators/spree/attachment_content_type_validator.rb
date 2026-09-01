# frozen_string_literal: true

module Spree
  # Checks an Active Storage attachment against an allowlist of content types,
  # deciding what a file is from its bytes rather than from the header the
  # uploader sent.
  #
  # This is the low-trust upload path: buyers attach purchase orders and
  # sellers attach registration documents, and an operator opens both on their
  # own machine. Without reading the bytes a shell script or an HTML page named
  # `po.pdf` passes, so the declared content type is discarded outright and the
  # filename is used only as described below.
  #
  # Reached through `validates_with` rather than a `validates` option, because
  # Rails resolves that shorthand against the model's own ancestry and would
  # not find a constant living in this namespace.
  #
  #   validates_with Spree::AttachmentContentTypeValidator,
  #                  attributes: [:po_document], in: CONTENT_TYPES
  #   validates_with Spree::AttachmentContentTypeValidator,
  #                  attributes: [:file], in: ->(record) { record.accepted }
  #
  # Marcel does the reading, which is deliberate: it ships with Active Storage
  # and identifies every type these allowlists carry without the Unix `file`
  # command, a binary absent from most slim container images and whose absence
  # otherwise surfaces to a buyer mid-checkout.
  #
  # @see Spree::Purchase::PurchaseOrder
  # @see Spree::SellerRequirementSubmission
  class AttachmentContentTypeValidator < ActiveModel::EachValidator
    # Office files are containers — a zip for the modern formats, an OLE
    # compound file for the older ones — and which office format a given
    # container holds is recorded in a part that can sit anywhere inside it.
    # Magic bytes alone therefore identify some of them only as the container,
    # however much of the file is read. For those types, and only those, the
    # extension breaks the tie.
    #
    # This is narrower than it looks. The container itself is still proven from
    # the bytes, so no script, document or executable can borrow the name: the
    # slack is that a plain zip renamed `.docx` is accepted as one. That is the
    # same answer a merchant's own machine gives when they double-click it.
    #
    # A container whose own marker happens to fall within the bytes read is
    # identified outright and never reaches the tie-break at all.
    CONTAINER_CONTENT_TYPES = %w[application/zip application/x-ole-storage].freeze

    # A misspelled or forgotten option would otherwise leave this validator
    # silently accepting everything, on the one path whose whole purpose is
    # refusing hostile files. An allowlist that resolves to empty at runtime is
    # still allowed — a submission whose requirement names no types accepts any.
    def check_validity!
      return if options.key?(:in) || options.key?(:with)

      raise ArgumentError, 'You must pass either :in or :with to the validator'
    end

    def validate_each(record, attribute, _value)
      attachment = record.public_send(attribute)
      return unless attachment.attached?

      permitted = permitted_content_types(record)
      return if permitted.empty?

      pending = pending_attachables(record, attribute)

      blobs_for(attachment).each_with_index do |blob, index|
        validate_blob(record, attribute, blob, permitted, pending[index])
      end
    end

    private

    def permitted_content_types(record)
      value = options[:in] || options[:with]
      value = value.call(record) if value.respond_to?(:call)

      Array.wrap(value).map(&:to_s)
    end

    # Serves both `has_one_attached` and `has_many_attached` without asking the
    # proxy to behave like an array, which the single-attachment one does not.
    def blobs_for(attachment)
      attachment.respond_to?(:blobs) ? attachment.blobs : [attachment.blob]
    end

    # Where the bytes live depends on how the file arrived. A direct upload — the
    # storefront and dashboard path — has already stored them and sends back a
    # signed id. An attachment handed raw IO, as seeds and imports do, has not
    # been uploaded yet: Active Storage holds it until the record saves, so it is
    # read from the pending attachable instead. Reading storage in that case
    # would find nothing and reject a file that is perfectly good.
    def pending_attachables(record, attribute)
      change = record.attachment_changes[attribute.to_s]
      return [] if change.nil?

      change.respond_to?(:attachables) ? Array(change.attachables) : [change.attachable]
    end

    def validate_blob(record, attribute, blob, permitted, attachable)
      return if blob.nil?

      return if permitted_bytes?(blob, attachable, permitted)

      record.errors.add(attribute, :spree_content_type_not_allowed)
    end

    def permitted_bytes?(blob, attachable, permitted)
      head = leading_bytes(blob, attachable)

      # Bytes that could not be read at all are somebody else's problem to
      # report — see {#leading_bytes} — and are not evidence of a bad file type.
      return true if head.nil?
      return false if head.empty?

      # No declared type is passed: Marcel falls back to it for bytes it cannot
      # read, which would hand the decision back to whoever uploaded the file.
      detected = Marcel::MimeType.for(StringIO.new(head))
      return true if permitted.include?(detected)
      return false unless CONTAINER_CONTENT_TYPES.include?(detected)

      permitted.include?(office_type_from_extension(blob))
    end

    # Asks the extension alone, rather than re-reading the bytes with a filename
    # attached. Marcel would only let the name win where it records the office
    # type as a descendant of the container, which it does for the zip-based
    # formats but not the OLE-based ones — so going through it would quietly
    # reject every legacy Word document whose internal marker sits beyond the
    # bytes we read.
    #
    # @return [String, nil]
    def office_type_from_extension(blob)
      filename = blob.filename.to_s
      return if File.extname(filename).blank?

      Marcel::MimeType.for(name: filename)
    end

    # Only the leading bytes are read: that is all a magic-number match needs,
    # and it keeps a 10 MB purchase order from being pulled into memory to
    # identify its first few bytes.
    #
    # @return [String, nil] the bytes, or nil when there are none to read
    def leading_bytes(blob, attachable)
      pending = pending_bytes(attachable)
      return pending if pending

      blob.service.download_chunk(blob.key, 0...MAGIC_BYTES_LENGTH)
    rescue ActiveStorage::FileNotFoundError
      # An abandoned direct upload leaves the blob row without its bytes. Saying
      # the type is wrong would misdescribe that, so this stays quiet and lets
      # the callers report the upload itself as incomplete.
      nil
    end

    # @return [String, nil] the head of a file not yet uploaded, leaving the
    #   caller's IO rewound so the upload itself still sees the whole thing
    def pending_bytes(attachable)
      case attachable
      when Pathname then attachable.open('rb') { |file| file.read(MAGIC_BYTES_LENGTH) }
      when Hash then read_head(attachable[:io])
      else read_head(attachable)
      end
    end

    # An uploaded file and a plain IO are both read in place and rewound: the
    # upload still has to send the whole file afterwards.
    def read_head(io)
      io = io.open if io.is_a?(ActionDispatch::Http::UploadedFile)
      return unless io.respond_to?(:read) && io.respond_to?(:rewind)

      begin
        io.rewind
        io.read(MAGIC_BYTES_LENGTH)
      ensure
        io.rewind
      end
    end

    MAGIC_BYTES_LENGTH = 4.kilobytes
    private_constant :MAGIC_BYTES_LENGTH
  end
end
