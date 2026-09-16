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

      # Resources whose controller writes through a Tier 1 service rather
      # than a workflow. Order editing, fees, discounts, addresses, stock
      # levels and store credits reach agents when those paths become
      # workflows (the 6.1 order-change substrate covers most of them), never
      # through a generic write that would bypass the orchestration the
      # service performs. See docs/plans/6.0-mcp-server.md, "What is not
      # exposed at 6.0".
      SERVICE_WRITTEN_MODELS = %w[
        Spree::Order
        Spree::Return
        Spree::Exchange
        Spree::Claim
        Spree::StockLevel
        Spree::StoreCredit
        Spree::Refund
        Spree::Payment
        Spree::ShippingLabel
        Spree::StockMovement
        Spree::StockReservation
        Spree::SellerPayout
        Spree::SellerTransfer
        Spree::Delivery
      ].freeze

      # Resources withheld whatever their controller says, because their
      # serializer carries a live credential or a bearer instrument. Every
      # tool result reaches a model and, for a hosted client, a third party.
      #
      #   api_keys, integrations, webhook_endpoints — plaintext tokens,
      #     provider credentials and the secret that signs deliveries.
      #   gift_cards — the code IS the instrument: whoever reads it can spend
      #     the balance. A balance tool that never emits a code could be added.
      WITHHELD_MODELS = %w[
        Spree::ApiKey
        Spree::Integration
        Spree::WebhookEndpoint
        Spree::GiftCard
      ].freeze

      class << self
        # Walks every admin resource controller and registers what it serves.
        #
        # @param map [Class] defaults to the core resource map
        # @return [Integer] how many resources were registered
        def install(map: Spree::AgentTools::ResourceMap)
          map.reset!

          controllers.each do |controller|
            entry = derive(controller)
            next if entry.nil?

            map.register(**entry)
          end

          map.all.size
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
            write_permission: write_permission_for(model, scope, create_workflow, update_workflow, writable),
            writable_attributes: writable,
            create_workflow_key: create_workflow,
            update_workflow_key: update_workflow
          }
        end

        private

        # A resource is generically writable only when the Admin API writes it
        # by saving the record, and the OpenAPI document says what a write may
        # set. A workflow-written resource keeps its workflow key instead (so
        # the refusal can name the tool); a service-written one is not writable
        # at all; and a resource with no documented body is read-only here,
        # because a write tool with no attributes is one an agent can only get
        # wrong.
        def write_permission_for(model, scope, create_workflow, update_workflow, writable)
          return if SERVICE_WRITTEN_MODELS.include?(model.name)
          return if create_workflow.present? || update_workflow.present?
          return if writable.empty?

          "write_#{scope}"
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

          !model.for_store(Spree::Store.new).equal?(model)
        rescue StandardError
          false
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
