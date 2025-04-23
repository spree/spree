module Spree
  module Admin
    class ErrorsController < Spree::Admin::BaseController
      skip_before_action :authorize_admin

      def show
        render "spree/admin/errors/#{status_code}", status: status_code
      end

      private

      def status_code
        params[:code].presence || request.env['PATH_INFO'].gsub('/', '') || 500
      end
    end
  end
end
