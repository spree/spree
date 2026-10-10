module Spree
  module AgentTools
    # Stores a file the merchant provided, through the Admin API's own upload
    # endpoint, and answers with the id every other write accepts.
    #
    # The dashboard uploads in two steps: ask for a presigned URL, then PUT
    # the bytes to it. An agent has no second request to make, and with the
    # disk service that URL points back at this same application — so the
    # endpoint takes the bytes directly and this is one dispatch.
    #
    # Storing a file is not yet using it: the id is attached by whichever
    # tool the merchant asked for next, under that tool's own permission.
    class UploadFile < Spree::AgentTool
      tool_name 'upload_file'
      description 'Store a file the merchant provided — a CSV to import, an image for a ' \
                  'product, a document to attach — and return the id other tools accept. ' \
                  'Send text as text; use encoding "base64" only for images, PDFs and other ' \
                  'binary files. Storing a file does nothing on its own.'
      # The endpoint's own gate, which is the same one the dashboard's
      # uploader passes.
      permission 'write_products'
      mutating!

      param :filename, description: 'The file name, with its extension', required: true
      param :content, description: 'The file contents — text as text, binary base64 encoded',
                      required: true
      param :encoding, description: '"base64" for a binary file; omit for text'
      param :content_type, description: "The file's media type, e.g. text/csv or application/pdf"

      def call(filename:, content:, encoding: nil, content_type: nil)
        response = ApiDispatch.new(context).call(
          method: :post,
          path: '/api/v3/admin/direct_uploads',
          body: {
            filename: filename,
            content: content,
            encoding: encoding.presence,
            content_type: content_type.presence,
            # Agent uploads land on private storage: a purchase order or a
            # customer list is not something to put behind a public URL.
            private: true
          }.compact
        )
        return { error: response.error_message } unless response.success?

        body = response.body.to_h

        {
          ok: true,
          file_id: body['signed_id'],
          filename: body['filename'],
          content_type: body['content_type'],
          byte_size: body['byte_size']
        }
      end

      def summary(arguments)
        "Store the file #{arguments[:filename]}"
      end
    end
  end
end
