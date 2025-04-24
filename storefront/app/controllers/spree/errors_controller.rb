module Spree
  class ErrorsController < StoreController
    def show
      render "spree/errors/#{status_code}", status: status_code
    end

    private

    def status_code
      # Extract a 3‑digit code from params or path, default to “500”
      code_str = params[:code].presence ||
                  request.path.match(%r{/(\d{3})$})&.[](1) ||
                   '500'
      code = code_str.to_i

      # Only allow valid 4xx/5xx error codes, fallback to 500
      valid_errors = Rack::Utils::HTTP_STATUS_CODES.keys.select { |c| c >= 400 }
      valid_errors.include?(code) ? code : 500
    end
  end
end
