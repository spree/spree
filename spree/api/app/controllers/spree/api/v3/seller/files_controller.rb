module Spree
  module Api
    module V3
      module Seller
        # A file stored here is attached to nothing until the seller sends its
        # `signed_id` to an endpoint that checks the target is theirs, so the
        # narrowest meaningful gate is the seller's own profile, which every
        # member of a seller's team holds.
        class FilesController < Seller::BaseController
          include Spree::Api::V3::FileUploads

          scoped_resource :seller_profile

          private

          def file_upload_serializer
            Spree.api.seller_file_upload_serializer
          end
        end
      end
    end
  end
end
