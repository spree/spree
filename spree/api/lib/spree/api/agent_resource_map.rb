module Spree
  module Api
    # Fills {Spree::AgentTools::ResourceMap} from the Admin API's own
    # controllers.
    #
    # Nothing here is a list. Every admin resource controller already declares
    # the model it serves, the serializer it renders, the permission scope it
    # rides and the workflow it writes through — so the map an agent reads is
    # the API surface by construction, and a resource cannot drift from the
    # endpoint that serves it. A controller that gains an attribute gains it
    # for agents in the same commit.
    #
    # The one fact a controller does not carry is where the record lives in the
    # dashboard, which is only used to link to it, so those are kept here.
    #
    # See docs/plans/6.0-mcp-server.md.
    module AgentResourceMap
      # Dashboard routes, for results that link to the record rather than
      # describing where to find it. Store-relative: the panel prefixes the
      # current store segment.
      DASHBOARD_PATHS = {
        'products' => '/products/%<id>s',
        'categories' => '/products/categories/%<id>s',
        'collections' => '/products/collections/%<id>s',
        'price_lists' => '/products/price-lists/%<id>s',
        'orders' => '/orders/%<id>s',
        'customers' => '/customers/%<id>s',
        'companies' => '/companies/%<id>s',
        'sellers' => '/sellers/%<id>s',
        'promotions' => '/promotions/%<id>s',
        'channels' => '/settings/channels',
        'markets' => '/settings/markets',
        'payment_methods' => '/settings/payment-methods',
        'delivery_profiles' => '/settings/delivery-profiles',
        'stock_locations' => '/settings/stock-locations',
        'tax_categories' => '/settings/tax-categories',
        'tax_rates' => '/settings/tax-rates',
        'product_types' => '/settings/product-types',
        'commission_rates' => '/settings/commission-rates',
        'roles' => '/settings/roles',
        'return_reasons' => '/settings/reasons',
        'allowed_origins' => '/settings/allowed-origins',
        'imports' => '/settings/imports'
      }.freeze

      # Resources withheld whatever their controller says, because their
      # serializer carries a live credential or a bearer instrument. Every
      # tool result reaches a model and, for a hosted client, a third party.
      #
      #   api_keys, integrations, webhook_endpoints — plaintext tokens,
      #     provider credentials and the secret that signs deliveries.
      #   gift_cards — the code IS the instrument: whoever reads it can spend
      #     the balance. A balance tool that never emits a code could be added.
      #   invitations   — the acceptance link is a bearer token that mints a
      #                   staff account at the invited role, and the endpoint
      #                   it addresses is deliberately unauthenticated. The
      #                   outbound filter drops the link, but a resource whose
      #                   whole purpose is handing out authority does not
      #                   belong on a read surface an agent drives.
      WITHHELD_MODELS = %w[
        Spree::ApiKey
        Spree::OauthApplication
        Spree::Integration
        Spree::WebhookEndpoint
        Spree::WebhookDelivery
        Spree::GiftCard
        Spree::Invitation
      ].freeze

      # Controllers that resolve their scope per request rather than declaring
      # one, because the scope belongs to the resource being imported or
      # exported — creating a product import is a product write, and reading
      # its rows exposes the uploaded data. A single static key cannot say
      # that, so these are registered read-only under the broadest key the
      # controller can demand, and the write path stays with the endpoint.
      DYNAMIC_SCOPE_RESOURCES = {
        'imports' => { model_name: 'Spree::Import', permission: 'read_settings',
                       serializer_name: 'Spree::Api::V3::Admin::ImportSerializer',
                       dashboard_path: '/settings/imports' },
        'exports' => { model_name: 'Spree::Export', permission: 'read_settings',
                       serializer_name: 'Spree::Api::V3::Admin::ExportSerializer' }
      }.freeze

      class << self
        # Registers this walk as how the core map fills itself, and marks the
        # map stale so the next reader gets a fresh one. Called on every code
        # reload; the walk itself runs when something actually reads the map.
        #
        # @return [void]
        def stale!
          Spree::AgentTools::ResourceMap.deriver = -> { install }
          Spree::AgentTools::ResourceMap.stale!
        end

        # Walks every admin resource controller and registers what it serves.
        #
        # @param map [Class] defaults to the core resource map
        # @return [Integer] how many resources were registered
        def install(map: Spree::AgentTools::ResourceMap)
          map.reset!

          registered = resolve_collisions(controllers.filter_map { |controller| derive(controller) })
          registered.each { |entry| map.register(**entry) }

          DYNAMIC_SCOPE_RESOURCES.each { |key, attributes| map.register(key: key, **attributes) }

          registered.size + DYNAMIC_SCOPE_RESOURCES.size
        end

        # Every admin resource controller in the application, the abstract
        # bases excluded. Eager-loaded first: in development only the
        # controllers already used would otherwise be known, and the map would
        # differ between a fresh boot and a warm one.
        #
        # @return [Array<Class>]
        def controllers
          Rails.application.eager_load! unless Rails.application.config.eager_load

          Spree::Api::V3::Admin::ResourceController.descendants.reject(&:abstract?).sort_by(&:name)
        end

        # What one controller contributes, or nil when it serves nothing an
        # agent can address.
        #
        # @param controller [Class]
        # @return [Hash, nil]
        # Where this controller's operations live, read from the routes rather
        # than guessed from the key: a nested or renamed resource keeps its
        # real path, and a controller with no route is not reachable at all.
        #
        # The shallowest route wins. A resource reached both at the top level
        # and under a parent (`/products` and
        # `/catalogs/:catalog_id/products`) is addressed by the former: a tool
        # given a product id has no parent id to fill in, and the nested route
        # would leave `:catalog_id` in the path.
        #
        # @return [Hash{Symbol => String}] action => path template
        # Across colliding controllers, the shallowest path per action.
        def shallowest_paths(candidates)
          candidates.flat_map { |entry| Array(entry[:api_paths]).to_a }.
            group_by(&:first).
            transform_values { |pairs| pairs.map(&:last).min_by { |path| [path.count(':'), path.length] } }
        end

        def api_paths_for(controller)
          candidates = Spree::Core::Engine.routes.routes.filter_map do |route|
            next unless route.defaults[:controller] == controller.controller_path

            action = route.defaults[:action]&.to_sym
            next if action.nil?

            [action, route.path.spec.to_s.sub('(.:format)', '')]
          end

          candidates.group_by(&:first).transform_values do |pairs|
            pairs.map(&:last).min_by { |path| [path.count(':'), path.length] }
          end
        end

        def derive(controller)
          instance = controller.allocate
          model = safely(instance, :model_class)
          return if model.nil? || WITHHELD_MODELS.include?(model.name)

          scope = controller._scoped_resource
          return if scope.blank?

          serializer = safely(instance, :serializer_class)
          return if serializer.nil?

          key = key_for(model)
          return unless store_scoped?(model)

          create_workflow = workflow_key(instance, :create_workflow)
          update_workflow = workflow_key(instance, :update_workflow)
          writable = AgentWriteSchemas.attribute_names(key)

          {
            key: key,
            model_name: model.name,
            permission: "read_#{scope}",
            serializer_name: serializer.name,
            dashboard_path: DASHBOARD_PATHS[key],
            api_paths: api_paths_for(controller),
            write_permission: write_permission_for(model, scope, create_workflow, update_workflow, writable, controller),
            writable_attributes: writable,
            create_workflow_key: create_workflow,
            update_workflow_key: update_workflow,
            distinct: collection_distinct?(instance)
          }
        end

        private

        # What the controller does with its own collection. A controller that
        # disables DISTINCT has a reason — Postgres refuses it beside an
        # ORDER BY the select list does not carry — and a search tool adding
        # it anyway answers with a 500.
        def collection_distinct?(instance)
          return true unless instance.respond_to?(:collection_distinct?, true)

          instance.send(:collection_distinct?)
        rescue StandardError
          true
        end

        # A model can be served by more than one controller under different
        # permission scopes — a tax identifier through customers and through
        # orders, media through products and through the media library. One
        # resource key can carry only one permission, and whichever controller
        # happened to sort last is not an answer: it would grant a key holding
        # `read_orders` the customers' records too.
        #
        # So a collision resolves to the narrowest scope offered, and the
        # resource stays read-only, because the two controllers do not agree
        # on who may write it. A caller holding the wider scope reaches the
        # record through the endpoint, as before.
        def resolve_collisions(entries)
          entries.group_by { |entry| entry[:key] }.map do |_key, candidates|
            next candidates.first if candidates.one?

            narrowest = candidates.min_by { |entry| [scope_breadth(entry[:permission]), entry[:permission]] }
            contested = candidates.map { |entry| entry[:permission] }.uniq.size > 1

            # A workflow declaration is not in dispute — whichever controller
            # declares one, that is how the resource is written, and the
            # refusal has to keep naming that tool. Only the generic write is
            # withdrawn, and only when the controllers disagree about the
            # scope guarding it.
            narrowest.merge(
              create_workflow_key: candidates.filter_map { |entry| entry[:create_workflow_key] }.first,
              update_workflow_key: candidates.filter_map { |entry| entry[:update_workflow_key] }.first,
              write_permission: contested ? nil : narrowest[:write_permission],
              writable_attributes: contested ? [] : narrowest[:writable_attributes],
              # One controller refusing DISTINCT is enough: its sort would
              # make Postgres reject the query, and whichever controller
              # happened to sort first is not an answer.
              distinct: candidates.all? { |entry| entry[:distinct] },
              # The shallowest route across every controller claiming this
              # key. `narrowest` is chosen by permission breadth, which says
              # nothing about depth — so a resource served both at the top
              # level and under a parent kept whichever won on scope, and a
              # tool was handed a path with an unfillable `:parent_id` in it.
              api_paths: shallowest_paths(candidates)
            )
          end
        end

        # How much a scope covers, so the narrowest wins a collision. Measured
        # by the number of resources the catalog grants it, which is the only
        # ranking the catalog actually gives us.
        def scope_breadth(permission)
          _kind, scope = Spree.permissions.resolve_key(permission)
          scope ? Array(scope.resources).size : Float::INFINITY
        rescue StandardError
          Float::INFINITY
        end

        # A resource is generically writable only when the Admin API writes it
        # by saving the record, and the OpenAPI document says what a write may
        # set. A workflow-written resource keeps its workflow key instead (so
        # the refusal can name the tool); a service-written one is not writable
        # at all; and a resource with no documented body is read-only here,
        # because a write tool with no attributes is one an agent can only get
        # wrong.
        # Writable when the controller documents a body and does not hand out
        # authority.
        #
        # The list of service-written models this used to consult is gone
        # (2026-10-10). It existed because a generic write assigned
        # attributes and saved, so reaching a record whose controller
        # orchestrates — an order, a refund, a stock level — would have
        # skipped that orchestration. A dispatched write IS the controller,
        # so there is nothing left to skip, and the list only withheld writes
        # the API performs correctly.
        #
        # A declared workflow no longer withholds it either: the controller
        # runs its own workflow, which is what the generic write now reaches.
        def write_permission_for(model, scope, create_workflow, update_workflow, writable, controller)
          return if writable.empty?
          return if hands_out_authority?(controller)

          "write_#{scope}"
        end

        # A controller that hands out authority — roles, role grants,
        # invitations, API keys — runs an anti-amplification check the generic
        # write knows nothing about: a caller may only grant permissions they
        # themselves hold. Assigning those attributes and calling `save` would
        # skip it, so writing them stays with the endpoint that guards them.
        #
        # Asked of the controller rather than listed, so a surface that adopts
        # the guard later is covered without anyone remembering this file.
        def hands_out_authority?(controller)
          return false unless defined?(Spree::Api::V3::Admin::RoleGrantGuard)

          controller.include?(Spree::Api::V3::Admin::RoleGrantGuard)
        rescue StandardError
          false
        end

        # The plural the resource is addressed by, taken from the model so two
        # controllers serving the same model (a nested one and a top-level one)
        # agree on it.
        def key_for(model)
          model.model_name.element.pluralize
        end

        # `Spree::Base.for_store` falls back to the bare class for a model with
        # no Store association, which would hand this store's agent every
        # store's rows. A model that defines its own `for_store` has made a
        # deliberate choice (customers are global by design and say so);
        # inheriting the fallback is an accident, and a missing resource is
        # better than a leaking one.
        def store_scoped?(model)
          return false unless model.respond_to?(:for_store)
          return true if model.method(:for_store).owner != Spree::Base.singleton_class

          !model.for_store(probe_store).equal?(model)
        rescue StandardError
          false
        end

        # One unsaved store, reused: the probe asks what `for_store` does with
        # a store, not with any particular one, and the walk covers every
        # admin controller.
        def probe_store
          @probe_store ||= Spree::Store.new
        end

        # The workflow a controller writes through, as its dotted key, so a
        # generic write can name the tool that does the job instead.
        def workflow_key(instance, method_name)
          workflow = safely(instance, method_name)
          workflow.respond_to?(:workflow_key) ? workflow.workflow_key : nil
        end

        # A controller may raise from any of these — `model_class` is
        # NotImplementedError on an abstract one, `permitted_attributes` reads
        # request state on a few — and one such controller must not take the
        # whole map down at boot.
        def safely(instance, method_name)
          instance.send(method_name)
        rescue StandardError, NotImplementedError
          nil
        end
      end
    end
  end
end
