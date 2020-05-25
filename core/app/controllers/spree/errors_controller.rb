module Spree
  class ErrorsController < Spree::BaseController
    def forbidden
      head 403
    end
  end
end
