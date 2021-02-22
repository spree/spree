module Spree
  class ErrorsController < BaseController
    def forbidden
      render status: 403
    end

    def unauthorized
      render status: 401
    end
  end
end
