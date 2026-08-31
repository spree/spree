# frozen_string_literal: true

module Spree
  # Confirms an attachment is the type it claims to be, from the bytes.
  #
  # {ActiveStorageValidations}' +spoofing_protection+ option does the same
  # job by shelling out to the Unix +file+ command, which is not in the
  # starter image and is not a Ruby dependency. Rails already ships Marcel,
  # which reads the same magic numbers in process. This validator uses that
  # so a stock install can accept a purchase-order or seller document
  # without an extra system package.
  #
  # @example
  #   validates :po_document, 'spree/bytes_content_type': { in: %w[application/pdf] }
  class BytesContentTypeValidator < ActiveModel::EachValidator
    # Marcel's Office Open XML signatures look past the zip header (up to
    # 64 KiB) for +[Content_Types].xml+ / +word/+. Images and PDFs need
    # only the first few bytes.
    HEADER_BYTES = 64.kilobytes

    # @param record [ActiveRecord::Base]
    # @param attribute [Symbol]
    # @param _value [Object]
    # @return [void]
    def validate_each(record, attribute, _value)
      attachment = record.public_send(attribute)
      return unless attachment.respond_to?(:attached?) && attachment.attached?

      blob = attachment.blob
      return if blob.nil?

      allowed = allowed_content_types(record)
      return if allowed.empty?

      detected = detect_content_type(blob)
      return if detected.blank?
      return if types_compatible?(blob.content_type, detected)

      record.errors.add(
        attribute,
        options[:message] || Spree.t(:attachment_content_type_mismatch)
      )
    rescue ActiveStorage::FileNotFoundError
      # An unfinished direct upload is a different failure; the attach
      # path already translates that into a retryable message.
    end

    private

    def allowed_content_types(record)
      types = options[:in] || options[:with]
      types = types.call(record) if types.respond_to?(:call)
      Array.wrap(types).compact
    end

    def detect_content_type(blob)
      header = blob.download_chunk(0...HEADER_BYTES)
      Marcel::MimeType.for(StringIO.new(header.to_s.b))
    end

    # A declared Word document whose bytes only identify as a zip (the
    # container) still matches: Marcel lists zip as a parent of the Office
    # Open XML type. A script declared as a PDF does not share a parent.
    def types_compatible?(declared, detected)
      enlarged(declared).intersect?(enlarged(detected))
    end

    def enlarged(content_type)
      type = content_type.to_s.split(/[;,\s]/, 2).first
      [type, *Array(Marcel::TYPE_PARENTS[type])].compact.uniq
    end
  end
end
