module Spree
  module AgentTools
    # Runs an Admin API operation for a tool, in this process.
    #
    # A tool names an operation; this is what reaches it. The request goes
    # through the whole stack — routing, authentication, the controller, the
    # serializer, the error format — so a tool reaches data the way any other
    # client does, and a guard added to the API protects agents without anyone
    # copying it here.
    #
    # Deliberately not HTTP to itself. A socket back to the same application
    # holds one web thread waiting on another, so a few concurrent tool calls
    # on a small pool deadlock the process, and it buys TLS, DNS and timeouts
    # for nothing.
    class ApiDispatch
      # What a dispatched call answers with.
      Response = Struct.new(:status, :body, :headers, keyword_init: true) do
        # @return [Boolean]
        def success?
          status.between?(200, 299)
        end

        # The error the API itself rendered, in its own words. A tool repeats
        # this rather than inventing a message, so a refusal reads the same
        # however it was reached.
        #
        # @return [String, nil]
        def error_message
          return if success?

          error = body.is_a?(Hash) ? body['error'] : nil
          return error if error.is_a?(String)
          return error['message'] if error.is_a?(Hash) && error['message'].present?

          "The request failed (#{status})."
        end

        # @return [Hash, Array, nil]
        def data
          body.is_a?(Hash) && body.key?('data') ? body['data'] : body
        end

        # @return [Hash, nil] pagination, when the operation is a listing
        def meta
          body['meta'] if body.is_a?(Hash)
        end
      end

      # Only what the Admin API reads. Anything else a client sent is the MCP
      # request's business, not the operation's.
      FORWARDED_HEADERS = %w[HTTP_AUTHORIZATION HTTP_X_SPREE_API_KEY HTTP_HOST].freeze

      # @param context [Spree::AgentTools::Context]
      def initialize(context)
        @context = context
      end

      # @param method [Symbol] :get, :post, :patch, :delete
      # @param path [String] the operation's full path, already interpolated —
      #   the resource map's paths are absolute (`/api/v3/admin/products`)
      # @param params [Hash] query parameters for a read
      # @param body [Hash, nil] the request body for a write
      # @return [Response]
      def call(method:, path:, params: {}, body: nil)
        env = build_env(method, path, params, body)

        # `Spree::Current` is an `ActiveSupport::CurrentAttributes`, which does
        # NOT reset for a request made inside another request — the executor
        # is re-entrant. Measured on this branch before this class existed: an
        # inner call left the outer store in place and overwrote its currency.
        #
        # So the outer state is copied, cleared so the inner request resolves
        # its own from its own headers, and put back whatever happened. The
        # restore has to sit in this method's own `ensure`: wrapped in a
        # helper that yields, it ran before the executor finished unwinding
        # and the outer values were lost again.
        saved = Spree::Current.attributes.to_a
        # `RequestStore` is per-request too, and the inner request's middleware
        # clears it on the way out — leaving `RequestStore.store` nil, which
        # the store scope guard indexes into on the outer request's next
        # query. Saved unconditionally, including when it is already empty:
        # restoring an empty hash is what keeps it a hash.
        saved_request_store = defined?(RequestStore) ? RequestStore.store.to_h.dup : nil

        begin
          status, headers, rack_body = Rails.application.call(env)
          Response.new(status: status, headers: headers, body: parse(rack_body))
        ensure
          # The executor flushes `ActiveSupport::ExecutionContext` as the
          # inner request unwinds, and that is where `CurrentAttributes` keeps
          # its per-thread instances — so the outer request's next read of
          # `Spree::Current` found no registry and raised inside Rails. A
          # frame has to be pushed back BEFORE the values are written, or the
          # writes land in a frame that is then replaced and read as nil.
          ActiveSupport::ExecutionContext.push if defined?(ActiveSupport::ExecutionContext)
          saved.each { |name, value| Spree::Current.public_send(:"#{name}=", value) }
          RequestStore.store = saved_request_store unless saved_request_store.nil?
        end
      end

      private

      def build_env(method, path, params, body)
        query = params.present? ? Rack::Utils.build_nested_query(stringify(params)) : nil
        payload = body.present? ? JSON.generate(body) : nil

        env = Rack::MockRequest.env_for(
          path,
          method: method.to_s.upcase,
          params: query,
          input: payload,
          'CONTENT_TYPE' => ('application/json' if payload)
        ).compact

        forwarded.each { |name, value| env[name] = value }
        env['HTTP_ACCEPT'] = 'application/json'
        env
      end

      # The credential the caller authenticated with, repeated verbatim. Never
      # an internal header that skips authentication: that would rebuild the
      # second security boundary this class exists to remove.
      def forwarded
        @context.request_headers.slice(*FORWARDED_HEADERS)
      end

      def parse(rack_body)
        text = +''
        rack_body.each { |chunk| text << chunk }
        rack_body.close if rack_body.respond_to?(:close)
        return if text.blank?

        JSON.parse(text)
      rescue JSON::ParserError
        nil
      end

      # Rack wants strings; a tool passes whatever the model sent.
      def stringify(params)
        params.to_h.deep_transform_keys(&:to_s)
      end
    end
  end
end
