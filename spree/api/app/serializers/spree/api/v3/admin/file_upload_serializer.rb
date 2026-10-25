module Spree
  module Api
    module V3
      module Admin
        class FileUploadSerializer < V3::FileUploadSerializer
          one :upload_target, key: :upload, resource: proc { Spree.api.admin_file_upload_target_serializer }
        end
      end
    end
  end
end
