module Spree
  module Api
    module Middleware
      class RequestSizeLimit
        # `POST /files` takes a file's bytes in the request itself, so it is
        # held to the multipart upload limit instead, plus room for the other
        # form fields.
        FILE_UPLOAD_PATH = %r{\A/api/v3/(admin|seller)/files/?\z}
        MULTIPART_ENVELOPE = 64.kilobytes

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
          content_length > max_body_size(env)
        end

        def max_body_size(env)
          return Spree::Config[:max_multipart_upload_size] + MULTIPART_ENVELOPE if file_upload?(env)

          @limit || Spree::Api::Config[:max_request_body_size]
        end

        def file_upload?(env)
          env['REQUEST_METHOD'] == 'POST' && FILE_UPLOAD_PATH.match?(env['PATH_INFO'])
        end
      end
    end
  end
end
