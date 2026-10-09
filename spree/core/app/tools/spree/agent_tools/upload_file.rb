module Spree
  module AgentTools
    # Takes a file the merchant handed over and stores it, answering with the
    # id every other write accepts.
    #
    # The dashboard uploads in two steps: ask for a presigned URL, then PUT
    # the bytes to it. An agent has no second request to make — its arguments
    # are JSON, so the file arrives as base64 and is stored here in one go.
    # What comes back is an ordinary ActiveStorage signed id, so nothing
    # downstream needs to know a model produced it.
    #
    # Storing a file is not yet using it: the id is attached by whichever
    # tool the merchant asked for next, under that tool's own permission.
    class UploadFile < Spree::AgentTool
      tool_name 'upload_file'
      description 'Store a file the merchant provided — a CSV to import, an image for a ' \
                  'product, a document to attach — and return the id other tools accept. ' \
                  'Send the bytes base64 encoded. Storing a file does nothing on its own; ' \
                  'pass the id to the tool that uses it.'
      # Storing a file changes nothing a merchant can see until the id is
      # used, so the permission that matters is the one on that write. This
      # gate is the floor: the same one the dashboard's upload endpoint uses.
      permission 'write_products'
      mutating!

      # Base64 is a third larger than the bytes it carries, and the whole
      # argument passes through the model's context on its way here. Beyond
      # this a file belongs in the dashboard's uploader.
      MAX_BYTES = 10.megabytes

      # What a merchant plausibly hands an agent. Deliberately not "anything":
      # a stored blob is attached later by a tool that may not check, and the
      # formats below are the ones the attachments themselves accept.
      PERMITTED_CONTENT_TYPES = %w[
        text/csv
        application/pdf
        image/jpeg
        image/png
        image/webp
        image/heic
        image/gif
        application/zip
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      ].freeze

      param :filename, description: 'The file name, with its extension', required: true
      param :content, description: 'The file bytes, base64 encoded', required: true
      param :content_type, description: "The file's media type, e.g. text/csv or application/pdf"

      def call(filename:, content:, content_type: nil)
        bytes = decode(content)
        return { error: 'content must be base64 encoded.' } if bytes.nil?
        return { error: 'The file is empty.' } if bytes.empty?
        return too_large(bytes) if bytes.bytesize > MAX_BYTES

        # Read from the bytes rather than trusting what the caller named it:
        # a model repeating a filename it was told is the same weak evidence
        # as an uploader's own header, which is why the attachment validators
        # look at content too.
        declared = content_type.presence || Marcel::MimeType.for(StringIO.new(bytes), name: filename)
        return unsupported(declared) unless PERMITTED_CONTENT_TYPES.include?(declared)

        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(bytes),
          filename: filename,
          content_type: declared,
          service_name: Spree.private_storage_service_name
        )

        {
          ok: true,
          file_id: blob.signed_id,
          filename: blob.filename.to_s,
          content_type: blob.content_type,
          byte_size: blob.byte_size
        }
      end

      def summary(arguments)
        "Store the file #{arguments[:filename]}"
      end

      private

      # A model that wrapped the payload in newlines is forgiven; one that
      # sent something else entirely is not. `decode64` cannot be used as the
      # test: it skips whatever it does not recognise, so a sentence of prose
      # decodes to a handful of bytes and the refusal that followed talked
      # about content types rather than about encoding.
      def decode(content)
        Base64.strict_decode64(content.to_s.gsub(/\s+/, ''))
      rescue ArgumentError
        nil
      end

      def too_large(bytes)
        {
          error: "That file is #{ActiveSupport::NumberHelper.number_to_human_size(bytes.bytesize)}. " \
                 "Files this tool stores must be under #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTES)} — " \
                 'upload a larger one from the dashboard.'
        }
      end

      def unsupported(content_type)
        {
          error: "This tool does not store #{content_type.inspect} files.",
          supported_content_types: PERMITTED_CONTENT_TYPES
        }
      end
    end
  end
end
