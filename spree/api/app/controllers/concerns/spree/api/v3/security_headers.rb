module Spree
  module Api
    module V3
      module SecurityHeaders
        extend ActiveSupport::Concern

        included do
          after_action :set_security_headers
        end

        private

        def set_security_headers
          response.headers['X-Content-Type-Options'] = 'nosniff'
          response.headers['X-Frame-Options'] = 'DENY'
          response.headers['X-Request-Id'] = request.request_id
          response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
          response.headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
          response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains' if request.ssl?
          response.headers.delete('X-Powered-By')
          response.headers.delete('Server')
        end
      end
    end
  end
end
