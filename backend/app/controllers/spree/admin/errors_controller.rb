module Spree
  module Admin
    class ErrorsController < BaseController
      def forbidden
        render status: 403
      end
    end
  end
end
