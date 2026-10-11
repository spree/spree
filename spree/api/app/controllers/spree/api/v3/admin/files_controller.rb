module Spree
  module Api
    module V3
      module Admin
        class FilesController < Admin::BaseController
          include Spree::Api::V3::FileUploads

          # The endpoint that uses a file checks its own scope (`write_customers`
          # for an avatar, and so on), so this gate is the floor, not the only
          # check. `write_products` covers the dominant flow, product media.
          scoped_resource :products

          skip_before_action :authenticate_user

          # Permitted by Spree::Api::V3::FileUploads, shared with the seller branch.
          request_params 'FileUploadCreateParams', action: :create do |body|
            body.include_attributes Spree::Api::V3::FileUploadRequestSchema
          end

          private

          def file_upload_serializer
            Spree.api.admin_file_upload_serializer
          end
        end
      end
    end
  end
end
