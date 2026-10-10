module Spree
  module Api
    module V3
      module Oauth
        # RFC 8414 Authorization Server Metadata.
        #
        # The document itself is entirely Doorkeeper's. Only URL generation is
        # Spree's problem: Doorkeeper asks for each endpoint by controller name
        # anchored at the application root, and these routes are drawn inside
        # an isolated engine, which cannot generate from such a name. The
        # injected resolver answers from the engine's own router instead.
        class ServerMetadataController < ::Doorkeeper::MetadataController
          private

          def metadata_response
            @metadata_response ||= ::Doorkeeper::OAuth::MetadataResponse.new(
              request.base_url,
              ->(**arguments) { resolve_endpoint(**arguments) }
            )
          end

          # Doorkeeper hands over a controller name anchored at the
          # application root (`/api/v3/…`), while the engine's router knows
          # its own controllers by their engine-qualified names
          # (`spree/api/v3/…`). Doorkeeper's own controllers are already
          # absolute and generate from the application router unchanged.
          def resolve_endpoint(**arguments)
            # Doorkeeper prepends a slash to whatever the route mapping
            # held, so a name configured as "/doorkeeper/tokens" arrives
            # doubled.
            name = arguments[:controller].to_s.sub(%r{\A/+}, '')

            if name.start_with?('doorkeeper/')
              return Spree::Core::Engine.routes.url_for(
                **arguments.except(:controller),
                controller: "/#{name}",
                only_path: false,
                host: request.host,
                protocol: request.protocol,
                port: request.optional_port
              )
            end

            Spree::Core::Engine.routes.url_for(
              **arguments.except(:controller),
              controller: "spree/#{name}",
              only_path: false,
              host: request.host,
              protocol: request.protocol,
              port: request.optional_port
            )
          end
        end
      end
    end
  end
end
