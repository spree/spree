module Spree
  module Assistant
    # The tool registry. Extensions append their own tool classes the same way
    # they register tax or delivery-rate providers:
    #
    #   Spree::Assistant.tools << MyApp::Assistant::Tools::SyncSupplier
    #
    # Registration is by class, so the same registry serves the chat adapter
    # today and an MCP server later.
    class Registry
      include Enumerable

      def initialize(tool_names = [])
        @tool_names = tool_names.map(&:to_s)
      end

      # Registered by name, resolved on use.
      #
      # Holding the class itself would pin the copy loaded at boot, so in
      # development every edit to a tool's description, params or permission
      # needed a restart to take effect — and tuning those descriptions is how
      # the assistant's behaviour is shaped. Names survive reloading, which is
      # the same reason `Spree.integrations` stores strings.
      #
      # @param tool_class [Class<Spree::Assistant::Tool>, String]
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

      # @return [Array<Class<Spree::Assistant::Tool>>]
      def to_a
        @tool_names.filter_map do |name|
          name.safe_constantize.tap do |klass|
            Rails.logger.warn("[Spree Assistant] registered tool #{name} does not exist") if klass.nil?
          end
        end
      end

      # @param name [String]
      # @return [Class<Spree::Assistant::Tool>, nil]
      def find_by_name(name)
        to_a.find { |tool_class| tool_class.tool_name == name.to_s }
      end

      # Tools the given admin may actually use, instantiated for this context.
      # This is what the model is offered — a user without `write_products`
      # never learns that a price-changing tool exists.
      #
      # @param context [Spree::Assistant::Context]
      # @return [Array<Spree::Assistant::Tool>]
      def available_for(context)
        to_a.map { |tool_class| tool_class.new(context) }.select(&:permitted?)
      end
    end
  end
end
