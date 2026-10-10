module Spree
  module Api
    module V3
      # A file accepted by an upload endpoint ({Spree::FileUpload}).
      #
      # `signed_id` is opaque: clients pass it back unchanged to the endpoint
      # that uses the file and never parse it. It stops being attachable at
      # `expires_at`. `upload` is where a presigned upload sends its bytes, and
      # null once the file is already stored.
      class FileUploadSerializer < BaseSerializer
        # A value object, not a record — it has no id of its own.
        _attributes.delete(:id)

        typelize signed_id: :string,
                 filename: :string,
                 content_type: :string,
                 byte_size: :number,
                 visibility: [:string, enum: Spree::FileUpload::VISIBILITIES],
                 expires_at: :string,
                 upload: [:FileUploadTarget, nullable: true]

        attributes :signed_id, :filename, :content_type, :byte_size, :visibility, expires_at: :iso8601

        one :upload_target, key: :upload, resource: proc { Spree.api.file_upload_target_serializer }
      end
    end
  end
end
