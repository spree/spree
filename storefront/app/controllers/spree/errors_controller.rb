module Spree
  class ErrorsController < StoreController
    def show
      render "spree/errors/#{status_code}", status: status_code
    end

    private

    def status_code
      params[:code].presence || request.env['PATH_INFO'].gsub('/', '') || 500
    end
  end
end
