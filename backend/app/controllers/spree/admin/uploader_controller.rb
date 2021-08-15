module Spree
  module Admin
    class UploaderController < Spree::Admin::BaseController
      skip_forgery_protection

      def image
        url_helper = Rails.application.routes.url_helpers

        blob = ActiveStorage::Blob.create_after_upload!(
          io: params[:file],
          filename: params[:file].original_filename,
          content_type: params[:file].content_type
        )

        render json: { location: url_helper.rails_blob_url(blob, only_path: true) }, content_type: 'text / html'
      end
    end
  end
end
