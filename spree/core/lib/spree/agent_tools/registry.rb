module Spree
  module AgentTools
    # The agent-tool registry, reached as {Spree.agent_tools}. Extensions append
    # their own tool classes the same way they register tax or delivery-rate
    # providers:
    #
    #   Spree.agent_tools << MyApp::AgentTools::SyncSupplier
    #
    # Registration is by class, so one registry serves every adapter: the MCP
    # server and the dashboard assistant both read it.
    #
    # Writes are not registered as classes. A back-office write already is a
    # workflow, so the registry exposes workflows by their `Spree::Dependencies`
    # key and derives each tool from the workflow's own `perform` signature —
    # see {#expose_workflows}.
    class Registry
      include Enumerable

      def initialize(tool_names = [])
        @tool_names = tool_names.map(&:to_s)
        @exposed_workflows = {}
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
        @tool_names << name unless @tool_names.include?(name)
        self
      end
      alias add <<

      def each(&)
        to_a.each(&)
      end

      # Exposes workflows as write tools, keyed by `Spree::Dependencies` key so
      # the tool follows whatever class the host app has registered:
      #
      #   Spree.agent_tools.expose_workflows(
      #     order_cancel_workflow: 'write_orders',
      #     product_activate_workflow: 'write_products'
      #   )
      #
      # A value may be the permission key on its own, or a hash carrying it
      # alongside `except:` (parameters to hide, such as a deprecated one) and
      # `summary:` (a callable overriding the generated confirmation line).
      #
      # @param exposures [Hash{Symbol => String, Hash}]
      # @return [self]
      def expose_workflows(**exposures)
        exposures.each do |dependency_key, options|
          options = { permission: options } if options.is_a?(String) || options.is_a?(Symbol)
          @exposed_workflows[dependency_key.to_sym] = {
            permission: options.fetch(:permission).to_s,
            except: Array(options[:except]).map(&:to_sym),
            summary: options[:summary]
          }
        end
        self
      end

      # @return [Hash{Symbol => Hash}] every exposed workflow, by dependency key
      attr_reader :exposed_workflows

      # @return [Array<Class<Spree::AgentTool>>]
      def to_a
        registered_classes + workflow_tool_classes
      end

      # Tools this caller may actually use, instantiated for their context.
      # This is what an adapter offers the model — a caller without
      # `write_products` never learns that a price-changing tool exists.
      #
      # @param context [Spree::AgentTools::Context]
      # @return [Array<Spree::AgentTool>]
      def available_for(context)
        to_a.map { |tool_class| tool_class.new(context) }.select(&:permitted?)
      end

      private

      def registered_classes
        @tool_names.filter_map do |name|
          name.safe_constantize.tap do |klass|
            Rails.logger.warn("[Spree] registered agent tool #{name} does not exist") if klass.nil?
          end
        end
      end

      # One generated tool class per exposed workflow whose dependency key
      # still resolves. A key an extension removed simply stops being offered
      # rather than breaking the whole catalog.
      def workflow_tool_classes
        @exposed_workflows.filter_map do |dependency_key, options|
          Spree::AgentTools::WorkflowTool.for(dependency_key, **options)
        end
      end
    end
  end
end
