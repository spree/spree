module Spree
  module Api
    module V3
      # `POST /files`: accepts a file for the current store and returns the
      # opaque, expiring `signed_id` an endpoint that uses the file takes
      # (docs/plans/6.0-uploads-and-file-ownership.md).
      #
      # A JSON request carries the file's metadata and gets back a storage
      # target to send the bytes to; a multipart request carries the bytes in
      # its `file` part. Shared by the admin and seller branches: a file
      # stored here is attached to nothing, so what differs is only the gate
      # each branch puts in front of it, which stays on the including
      # controller as its `scoped_resource`.
      module FileUploads
        extend ActiveSupport::Concern

        def create
          file_upload = Spree::FileUpload.new(store: current_store, **file_upload_params)

          if file_upload.save
            render json: file_upload_serializer.new(file_upload, params: serializer_params).to_h, status: :created
          else
            render_validation_error(file_upload.errors)
          end
        end

        private

        def file_upload_params
          params.permit(:filename, :content_type, :byte_size, :checksum, :visibility, :file).to_h.symbolize_keys
        end
      end
    end
  end
end
