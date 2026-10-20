module Spree
  module Api
    module V3
      module Seller
        class FileUploadSerializer < V3::FileUploadSerializer
          one :upload_target, key: :upload, resource: proc { Spree.api.seller_file_upload_target_serializer }
        end
      end
    end
  end
end
