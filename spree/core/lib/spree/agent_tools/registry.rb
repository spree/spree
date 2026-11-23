module Spree
  module AgentTools
    # The agent-tool registry. One per surface, the way the authentication
    # strategies are split — {Spree.admin_agent_tools} for the back office,
    # {Spree.store_agent_tools} for the storefront. Extensions append their
    # own tool classes the same way they register tax or delivery-rate
    # providers:
    #
    #   Spree.admin_agent_tools << MyApp::AgentTools::SyncSupplier
    #
    # Registration is by class, so one registry serves every adapter on its
    # surface: the MCP server and the dashboard assistant both read the admin
    # one.
    #
    # A tool also declares the surface it belongs to, so filing one in the
    # wrong registry is refused rather than discovered when a storefront
    # visitor is offered the back office. Ten admin tools carry no permission
    # of their own — they are gated per resource instead — so the registry
    # cannot be the only thing keeping them apart.
    #
    # Writes are not registered as classes. Every Admin API action an admin
    # key may call is already a tool, built from its OpenAPI operation by
    # {OperationCatalog} — see docs/plans/6.0-agent-tools-from-openapi.md.
    class Registry
      include Enumerable

      # @return [Symbol] the surface this registry serves
      attr_reader :audience

      def initialize(tool_names = [], audience: :admin)
        @tool_names = tool_names.map(&:to_s)
        @exposed_workflows = {}
        @audience = audience.to_sym
      end

      # Registered by name, resolved on use.
      #
      # Holding the class itself would pin the copy loaded at boot, so in
      # development every edit to a tool's description, params or permission
      # needed a restart to take effect — and tuning those descriptions is how
      # an agent's behaviour is shaped. Names survive reloading, which is the
      # same reason `Spree.integrations` stores strings.
      #
      # @param tool_class [Class<Spree::AgentTool>, String]
      # @return [self]
      def <<(tool_class)
        name = tool_class.to_s
        declared = tool_class.try(:audience)
        if declared && declared != audience
          raise ArgumentError,
                "#{name} belongs to the #{declared} surface and cannot be registered on the #{audience} one"
        end

        @tool_names << name unless @tool_names.include?(name)
        self
      end
      alias add <<

      def each(&)
        to_a.each(&)
      end

      # @deprecated Admin API operations are agent tools on their own, built
      #   from the OpenAPI document, so there is nothing to expose. A
      #   workflow behind a documented endpoint is that endpoint's tool; one
      #   without is not offered. Recorded and otherwise ignored, and removed
      #   in 7.0.
      #
      # @param exposures [Hash{Symbol => String, Hash}]
      # @return [self]
      def expose_workflows(**exposures)
        Spree::Deprecation.warn(
          'Spree.admin_agent_tools.expose_workflows is deprecated and has no effect: every documented ' \
          'Admin API action is an agent tool, built from its OpenAPI operation. A workflow reaches agents ' \
          'through an admin endpoint whose rswag spec is generated into the openapi/admin.yaml your gem ships. ' \
          'See docs/plans/6.0-agent-tools-from-openapi.md.'
        )

        @exposed_workflows.merge!(exposures.transform_keys(&:to_sym))
        self
      end

      # @deprecated see {#expose_workflows}
      # @return [Hash{Symbol => Hash}] what was passed to {#expose_workflows}
      attr_reader :exposed_workflows

      # @return [Array<Class<Spree::AgentTool>>]
      def to_a
        registered = registered_classes
        registered + operation_tool_classes(registered.map(&:tool_name))
      end

      # A tool this caller may use, by name — including a 6.0.0 name that is
      # no longer listed but still answers through 6.0.x, so a client that
      # learned it keeps working.
      #
      # @param name [String]
      # @param context [Spree::AgentTools::Context]
      # @return [Spree::AgentTool, nil]
      def find_for(name, context)
        name = name.to_s
        tool_class = registered_classes.find { |klass| klass.tool_name == name }
        if tool_class.nil? && operations?
          entry = Spree::AgentTools::OperationCatalog.find(name)
          tool_class = entry && Spree::AgentTools::OperationTool.for(entry)
        end
        return if tool_class.nil? || (tool_class.try(:audience) && tool_class.audience != audience)

        tool = tool_class.new(context)
        tool if tool.permitted?
      end

      # Tools this caller may actually use, instantiated for their context.
      # This is what an adapter offers the model — a caller without
      # `write_products` never learns that a price-changing tool exists.
      #
      # @param context [Spree::AgentTools::Context]
      # @return [Array<Spree::AgentTool>]
      def available_for(context)
        to_a.
          select { |tool_class| tool_class.try(:audience).nil? || tool_class.audience == audience }.
          map { |tool_class| tool_class.new(context) }.
          select(&:permitted?)
      end

      private

      def registered_classes
        @tool_names.filter_map do |name|
          name.safe_constantize.tap do |klass|
            Rails.logger.warn("[Spree] registered agent tool #{name} does not exist") if klass.nil?
          end
        end
      end

      # One tool per operation the catalog lists. Operations are back-office
      # actions, so only the admin surface offers them.
      #
      # A registered tool keeps its name: an operation claiming the same one
      # would make an MCP server refuse the whole list. The contract spec
      # fails on such a clash; at runtime it is logged, once per name.
      def operation_tool_classes(taken)
        return [] unless operations?

        Spree::AgentTools::OperationCatalog.all.filter_map do |entry|
          next Spree::AgentTools::OperationTool.for(entry) unless taken.include?(entry.name)

          warn_shadowed(entry.name)
          nil
        end
      end

      def warn_shadowed(name)
        @shadowed ||= Set.new
        return unless @shadowed.add?(name)

        Rails.logger.warn("[Spree] agent tool #{name} is registered by hand; the operation of that name is not offered")
      end

      def operations?
        audience == :admin
      end
    end
  end
end
