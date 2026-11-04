module Spree
  module Api
    # Fills {Spree::AgentTools::OperationCatalog} from the merged Admin API
    # document ({AdminDocument}) and the routes behind it.
    #
    # Every write operation that is not a resource's plain create, update or
    # destroy becomes a tool — cancel, capture, approve, send — unless its
    # spec opts it out with a reason. CRUD stays with the generic tools, and a
    # read becomes a tool only when its spec opts it in. Nothing here is a
    # list of tools: an endpoint that gains an rswag spec is a tool in the
    # same commit, core's or an extension's.
    #
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    module AgentOperations
      WRITE_VERBS = %w[post patch put delete].freeze
      CRUD_ACTIONS = %w[index show create update destroy].freeze
      ADMIN_PREFIX = '/api/v3/admin/'.freeze

      # The opt-out and opt-in marks an rswag spec sets (see the `agent_tool`
      # spec helper), and the reason an opt-out must carry.
      AGENT_KEY = 'x-spree-agent'.freeze
      REASON_KEY = 'x-spree-agent-reason'.freeze

      # The line `admin_scope` appends to a description. It is for the
      # rendered docs; a tool is already offered only to a key holding it.
      SCOPE_NOTE = /^\*\*Required scope:\*\*.*$/

      class << self
        # Registers this walk as how the catalog fills itself, and marks it
        # stale so the next reader gets a fresh one.
        #
        # @return [void]
        def stale!
          Spree::AgentTools::OperationCatalog.deriver = -> { install }
          Spree::AgentTools::OperationCatalog.stale!
          Spree::AgentTools::OperationTool.clear_cache!
          AdminDocument.refresh!
          AgentWriteSchemas.reset!
        end

        # @param catalog [Module] defaults to the core catalog
        # @return [Integer] how many operations were registered
        def install(catalog: Spree::AgentTools::OperationCatalog)
          catalog.reset!
          @models = {}

          by_route = candidates.index_by { |candidate| [candidate[:verb], candidate[:path]] }
          included = by_route.values.select { |candidate| disposition(candidate) == :included }
          listed = resolve_collisions(included.filter_map { |candidate| safe_entry_for(candidate) })
          listed.each { |entry| catalog.register(**entry) }
          register_aliases(catalog, by_route, listed.to_set { |entry| entry[:name] })

          listed.size
        end

        # Every admin operation in the document, with the route and
        # controller it resolves to. Public for the contract spec, which
        # reports the operations that resolve to nothing.
        #
        # @return [Array<Hash>]
        def candidates
          routes = route_index

          Array(AdminDocument.document['paths']).flat_map do |path, operations|
            next [] unless path.is_a?(String) && path.start_with?(ADMIN_PREFIX) && operations.is_a?(Hash)

            operations.filter_map do |verb, operation|
              next unless operation.is_a?(Hash) && (WRITE_VERBS + ['get']).include?(verb)

              { path: path, verb: verb, operation: operation, route: routes[[verb, path]],
                path_parameters: Array(operations['parameters']) }
            end
          end
        end

        # Whether an operation becomes a listed tool, and if not, why.
        #
        # @param candidate [Hash]
        # @return [Symbol] :included, :crud, :read, :opted_out, :unrouted,
        #   :unscoped or :withheld
        def disposition(candidate)
          return :unrouted if candidate[:route].nil?

          controller = candidate[:route][:controller]
          return :unscoped if controller.nil? || scope_of(controller).blank?
          return :withheld if withheld?(controller)

          flag = candidate[:operation][AGENT_KEY]
          return :opted_out if flag == false

          if candidate[:verb] == 'get'
            flag == true ? :included : :read
          elsif CRUD_ACTIONS.include?(candidate[:route][:action])
            # A create that is really an action — receiving stock against a
            # transfer — names its tool explicitly, and is then offered as one.
            candidate[:operation]['operationId'].present? ? :included : :crud
          else
            :included
          end
        end

        # Every admin route, with its path in OpenAPI form, from the engine's
        # routes — where an extension's admin routes are drawn too. Public for
        # the contract spec, which checks each against the document.
        #
        # @return [Array<Hash>] `{verb:, path:, controller:, action:}`
        def admin_routes
          Spree::Core::Engine.routes.routes.flat_map do |route|
            controller_path = route.defaults[:controller].to_s
            next [] unless controller_path.start_with?('spree/api/v3/admin')

            path = route.path.spec.to_s.sub('(.:format)', '').gsub(/:([a-z_]+)/, '{\1}')
            route.verb.to_s.split('|').map do |verb|
              { verb: verb.downcase, path: path, controller: controller_class(controller_path),
                action: route.defaults[:action].to_s }
            end
          end
        end

        # The tool name an operation gets: its `operationId`, or the resource
        # and the action.
        #
        # @return [String]
        def tool_name(candidate)
          candidate[:operation]['operationId'].presence ||
            "#{resource_key(candidate[:route][:controller])}_#{candidate[:route][:action]}"
        end

        private

        # One operation the catalog cannot read is left out and logged, rather
        # than taking every other tool down with it: validating a document's
        # shape up front cannot foresee every way a generated file goes wrong.
        def safe_entry_for(candidate)
          entry_for(candidate)
        rescue StandardError => e
          Rails.logger.error("[Spree] agent tool for #{candidate[:verb].upcase} #{candidate[:path]} left out: " \
                             "#{e.class}: #{e.message}")
          nil
        end

        def entry_for(candidate)
          operation = candidate[:operation]
          controller = candidate[:route][:controller]
          name = tool_name(candidate)
          read = candidate[:verb] == 'get'
          # A read takes its arguments as query parameters, a write as its body.
          body = read ? query_schema(Array(candidate[:path_parameters]) + Array(operation['parameters'])) : request_body(operation)

          {
            name: name,
            verb: candidate[:verb],
            path: candidate[:path],
            summary: operation['summary'].to_s,
            description: description_for(operation),
            permission: "#{scope_kind(controller, candidate[:route][:action])}_#{scope_of(controller)}",
            resource_key: resource_key(controller),
            path_params: candidate[:path].scan(/\{([a-z_]+)\}/).flatten,
            path_descriptions: path_descriptions(candidate[:path_parameters] + Array(operation['parameters'])),
            body_properties: body.fetch('properties', {}),
            body_required: Array(body['required']),
            legacy_parameters: Spree::AgentTools::LegacyTools.parameters_for(name, candidate[:verb], candidate[:path])
          }
        end

        # A 6.0.0 tool whose name is no longer derived — it pointed at a
        # create, or carried its workflow's name — stays callable through
        # 6.0.x, unlisted, under that name.
        def register_aliases(catalog, by_route, listed_names)
          # The catalog is still being filled, so the names already offered
          # are passed in rather than read back from it.
          Spree::AgentTools::LegacyTools::TOOLS.each do |old, tool|
            next if listed_names.include?(old)

            candidate = by_route[[tool[:verb], tool[:path]]]
            next unless candidate && %i[included crud].include?(disposition(candidate))

            entry = safe_entry_for(candidate)
            catalog.register_alias(**entry, name: old, legacy_parameters: tool[:parameters]) if entry
          end
        end

        # Two operations deriving one name: the shallower path keeps it, and
        # the contract spec fails so the other gets an `operationId`.
        def resolve_collisions(entries)
          entries.group_by { |entry| entry[:name] }.map do |name, claimants|
            next claimants.first if claimants.one?

            kept = claimants.min_by { |entry| [entry[:path].count('{'), entry[:path].length] }
            Rails.logger.warn("[Spree] agent tool #{name} is derived by #{claimants.size} operations; " \
                              "#{kept[:verb].upcase} #{kept[:path]} keeps it")
            kept
          end
        end

        # The summary, then the description's opening paragraph: what the
        # operation does, in the words its spec already reviews.
        def description_for(operation)
          prose = operation['description'].to_s.gsub(SCOPE_NOTE, '').strip
          paragraph = prose.split(/\n\s*\n/).first.to_s.squish

          [operation['summary'].to_s.strip.delete_suffix('.'), paragraph].compact_blank.join('. ')
        end

        # Path-level parameters first, so an operation's own description of a
        # segment wins.
        def path_descriptions(parameters)
          parameters.map { |parameter| AdminDocument.resolve_parameter(parameter) }.each_with_object({}) do |parameter, result|
            next unless parameter.is_a?(Hash) && parameter['in'] == 'path'

            result[parameter['name']] = parameter['description'] if parameter['description'].present?
          end
        end

        # Path-level parameters first, so an operation's own one of the same
        # name wins.
        def query_schema(parameters)
          parameters = parameters.map { |parameter| AdminDocument.resolve_parameter(parameter) }.
                       select { |parameter| parameter.is_a?(Hash) && parameter['in'] == 'query' }.
                       reverse.uniq { |parameter| parameter['name'] }.reverse
          properties = parameters.to_h do |parameter|
            [parameter['name'], json_schema(AdminDocument.inline(parameter['schema'] || {}).merge(
              { 'description' => parameter['description'] }.compact
            ))]
          end

          { 'properties' => properties, 'required' => parameters.select { |p| p['required'] }.map { |p| p['name'] } }
        end

        def request_body(operation)
          content = operation['requestBody'].is_a?(Hash) ? operation['requestBody']['content'] : nil
          schema = content.is_a?(Hash) ? content.dig('application/json', 'schema') : nil
          schema ? json_schema(AdminDocument.inline(schema)) : {}
        end

        # OpenAPI 3.0 marks a nullable field with `nullable: true`; JSON
        # Schema, which a client validates arguments against, says it with a
        # type list.
        def json_schema(schema)
          case schema
          when Array then schema.map { |item| json_schema(item) }
          when Hash
            converted = schema.except('nullable').transform_values { |value| json_schema(value) }
            if schema['nullable'] == true && converted['type'].is_a?(String)
              converted['type'] = [converted['type'], 'null']
            end
            converted
          else schema
          end
        end

        # [verb, OpenAPI path] => the action behind it.
        def route_index
          admin_routes.each_with_object({}) do |route, index|
            index[[route[:verb], route[:path]]] ||= route.slice(:controller, :action)
          end
        end

        def controller_class(controller_path)
          "#{controller_path}_controller".camelize.safe_constantize
        end

        def scope_of(controller)
          controller.try(:_scoped_resource)
        end

        # The scope kind the endpoint itself demands for an action — `read`
        # for the controller's read actions, `write` otherwise — so a tool is
        # offered to exactly the keys the endpoint will let through.
        def scope_kind(controller, action)
          instance = controller.allocate
          reads = instance.respond_to?(:read_actions, true) ? instance.send(:read_actions) : %w[index show]
          Array(reads).map(&:to_s).include?(action) ? 'read' : 'write'
        rescue StandardError, NotImplementedError
          'write'
        end

        # Controllers whose records carry a live credential — the ones the
        # resource map withholds — offer no tools either: an action on an API
        # key or a webhook endpoint answers with the secret.
        def withheld?(controller)
          model = model_for(controller)
          model && AgentResourceMap::WITHHELD_MODELS.include?(model.name)
        end

        # Keyed the way the resource map keys the model, so a tool's
        # resource_key finds its entry there.
        def resource_key(controller)
          model = model_for(controller)
          model ? AgentResourceMap.key_for(model) : controller.controller_name
        end

        # Once per controller per derivation: every operation it serves asks.
        def model_for(controller)
          (@models ||= {}).fetch(controller) { @models[controller] = AgentResourceMap.model_for(controller) }
        end
      end
    end
  end
end
