module Spree
  module Api
    module Middleware
      # Marks every API response as not for search engines. Store API JSON is
      # public and gets indexed once a crawler finds a link to it, where it
      # competes with the storefront's own pages; tokened URLs such as digital
      # downloads travel in emails, which is exactly how crawlers find them.
      #
      # A middleware rather than a controller callback: it also covers the
      # OAuth and webhook controllers that do not inherit from the API base
      # controller, and the 404 Rails renders for an unknown API path. Scoped
      # by path because the same application may serve pages that must stay
      # indexable.
      class NoIndex
        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, body = @app.call(env)
          headers['x-robots-tag'] = 'noindex, nofollow' if api_request?(env)
          [status, headers, body]
        end

        private

        def api_request?(env)
          env['PATH_INFO']&.start_with?('/api/')
        end
      end
    end
  end
end
