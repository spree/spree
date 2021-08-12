module Spree
  module Admin
    class ErrorsController < BaseController
      skip_before_action :authorize_admin

      def forbidden
        render status: 403
      end
    end
  end
end
