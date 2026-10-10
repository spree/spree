module Spree
  module Api
    # Which Admin API operation runs each workflow, derived rather than listed.
    #
    # Walk the admin routes; for each one, read the controller source and ask
    # whether the action behind it calls that workflow. The verb and path come
    # from the route, and the body keys from the generated OpenAPI document —
    # which is the only place that records a rename (a cancellation's
    # `reason:` keyword travels as `cancel_reason_id`).
    #
    # Read off the controllers for the same reason {AgentResourceMap} is: a
    # workflow that gains an endpoint is dispatched without anyone editing a
    # file, and one whose endpoint goes away stops being dispatched.
    module AgentWorkflowEndpoints
      # Where a controller declares a workflow for the base class to run,
      # rather than calling it inside an action of its own.
      DECLARED_IN = { 'create_workflow' => 'create', 'update_workflow' => 'update' }.freeze

      class << self
        # @param map [Module]
        # @return [Integer] how many workflows were mapped
        def install(map: Spree::AgentTools::WorkflowEndpoints)
          map.reset!
          keys = Spree::AgentTools::DefaultCatalog::WORKFLOWS.keys
          document = openapi_document

          admin_routes.each do |route|
            source = controller_source(route[:controller])
            next if source.nil?

            keys.each do |key|
              # `find` would derive, and deriving is what this is — read the
              # entries already registered instead.
              next if map.registered.key?(key)
              next unless action_calling(source, key) == route[:action]

              map.register(key: key, verb: route[:verb], path: route[:path],
                           body_keys: body_keys_for(document, route))
            end
          end

          map.registered.size
        end

        private

        def admin_routes
          Spree::Core::Engine.routes.routes.filter_map do |route|
            controller = route.defaults[:controller].to_s
            next unless controller.start_with?('spree/api/v3/admin')

            { controller: controller, action: route.defaults[:action].to_s,
              verb: route.verb.to_s, path: route.path.spec.to_s.sub('(.:format)', '') }
          end
        end

        # Which action calls this workflow: the `def` nearest above the call.
        # A declaration consumed by the base class names the action it serves
        # instead.
        def action_calling(source, key)
          index = source.index("Spree.#{key}")
          return if index.nil?

          enclosing = source[0...index].scan(/^\s+def ([a-z_]+)/).flatten.last
          DECLARED_IN.fetch(enclosing, enclosing)
        end

        def controller_source(controller_path)
          @sources ||= {}
          return @sources[controller_path] if @sources.key?(controller_path)

          @sources[controller_path] = begin
            klass = "#{controller_path.camelize}Controller".safe_constantize
            file = klass && Object.const_source_location(klass.name)&.first
            file && File.exist?(file) ? File.read(file) : nil
          rescue StandardError
            nil
          end
        end

        # What the operation's request body accepts, in the names the wire
        # uses. A workflow keyword and its body key often differ, and the
        # document is where that difference is recorded.
        def body_keys_for(document, route)
          operation = document.dig('paths', openapi_path(route[:path]), route[:verb].downcase)
          schema = operation&.dig('requestBody', 'content', 'application/json', 'schema')

          (schema&.dig('properties') || {}).keys
        end

        def openapi_path(path)
          path.gsub(/:([a-z_]+)/) { "{#{Regexp.last_match(1)}}" }
        end

        # A packaged installation has no docs/ directory, and a body the
        # document does not describe is simply passed through unchecked.
        #
        # `AgentWriteSchemas` already holds this file parsed, so it is read
        # through there rather than a second time: the document is nearly a
        # megabyte, and parsing it twice at boot is a second of nothing.
        def openapi_document
          Spree::Api::AgentWriteSchemas.document
        rescue StandardError => e
          Rails.logger.warn("[Spree] could not read the admin API document: #{e.class}: #{e.message}")
          {}
        end
      end
    end
  end
end
