module Spree
  module Api
    module Middleware
      class RequestSizeLimit
        def initialize(app, limit: nil)
          @app = app
          @limit = limit
        end

        def call(env)
          if api_request?(env) && content_length_exceeded?(env)
            body = { error: { code: 'request_too_large', message: 'Request body too large' } }
            [413, { 'Content-Type' => 'application/json' }, [body.to_json]]
          else
            @app.call(env)
          end
        end

        private

        def api_request?(env)
          env['PATH_INFO']&.start_with?('/api/v3/')
        end

        def content_length_exceeded?(env)
          content_length = env['CONTENT_LENGTH'].to_i
          content_length > max_body_size
        end

        def max_body_size
          @limit || Spree::Api::Config[:max_request_body_size]
        end
      end
    end
  end
end
