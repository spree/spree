module Spree
  module Api
    module V2
      module Platform
        class ImagesController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :upload

          def upload
            url_helpers = Rails.application.routes.url_helpers

            blob = ActiveStorage::Blob.create_after_upload!(
              io: params[:file],
              filename: params[:file].original_filename,
              content_type: params[:file].content_type
            )
            render json: { location: url_helpers.rails_blob_url(blob, only_path: true) }, content_type: 'text / html'
          end
        end
      end
    end
  end
end
