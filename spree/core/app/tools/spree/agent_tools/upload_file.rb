module Spree
  module AgentTools
    # Stores a file the merchant provided, through the Admin API's own upload
    # endpoint, and answers with the id every other write accepts.
    #
    # The dashboard uploads in two steps: ask for a storage target, then PUT
    # the bytes to it. An agent has no second request to make, so this sends
    # the bytes with the request — the multipart shape `POST /files` already
    # accepts — and the endpoint owns the type allowlist, the size cap and
    # which store the file belongs to.
    #
    # Storing a file is not yet using it: the id is attached by whichever
    # tool the merchant asked for next, under that tool's own permission.
    class UploadFile < Spree::AgentTool
      tool_name 'upload_file'
      description 'Store a file the merchant provided — a CSV to import, an image for a ' \
                  'product, a document to attach — and return the id other tools accept. ' \
                  'Send text as text; use encoding "base64" only for images, PDFs and other ' \
                  'binary files. Storing a file does nothing on its own.'
      # The endpoint's own floor, which is the gate the dashboard's uploader
      # passes; whatever uses the file checks its own permission after.
      permission 'write_products'
      mutating!

      param :filename, description: 'The file name, with its extension', required: true
      param :content, description: 'The file contents — text as text, binary base64 encoded',
                      required: true
      param :encoding, description: '"base64" for a binary file; omit for text'
      param :content_type, description: "The file's media type, e.g. text/csv or application/pdf"

      # A private upload accepts any type, which is right for the dashboard —
      # a merchant picking a file has already decided. A model repeating a
      # filename back has decided nothing, so an agent is held to the kinds
      # it has a reason to send.
      PERMITTED_CONTENT_TYPES = %w[
        text/csv
        text/plain
        application/pdf
        image/jpeg
        image/png
        image/webp
        image/gif
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      ].freeze

      def call(filename:, content:, encoding: nil, content_type: nil)
        bytes, error = decode(content, encoding)
        return { error: error } if error

        # Read from the bytes, not from what the caller named it: Marcel
        # places the content first, so a renamed script is not a CSV.
        kind = Marcel::MimeType.for(StringIO.new(bytes), name: filename,
                                                         declared_type: content_type.presence)
        unless PERMITTED_CONTENT_TYPES.include?(kind)
          return { error: "Files of type #{kind.inspect} are not accepted here.",
                   supported_content_types: PERMITTED_CONTENT_TYPES }
        end

        response = ApiDispatch.new(context).call(
          method: :post,
          path: '/api/v3/admin/files',
          body: {
            'filename' => filename,
            'content_type' => kind,
            # Agent uploads are private: a purchase order or a customer list
            # is not something to put behind a public URL, and a private
            # upload is the one that accepts a document at all.
            'visibility' => 'private',
            'file' => StringIO.new(bytes)
          }.compact
        )
        return { error: response.error_message } unless response.success?

        data = response.data.to_h

        {
          ok: true,
          file_id: data['signed_id'],
          filename: data['filename'],
          content_type: data['content_type'],
          byte_size: data['byte_size']
        }
      end

      def summary(arguments)
        "Store the file #{arguments[:filename]}"
      end

      private

      # Text arrives as text. Base64 is a third larger and a model has to
      # emit every byte of it, so it is asked for only where the bytes are
      # not text at all.
      def decode(content, encoding)
        raw = content.to_s
        return [raw, nil] unless encoding.to_s == 'base64'

        [Base64.strict_decode64(raw.gsub(/\s+/, '')), nil]
      rescue ArgumentError
        [nil, 'content is not valid base64. Send text as text, without the encoding parameter.']
      end
    end
  end
end
