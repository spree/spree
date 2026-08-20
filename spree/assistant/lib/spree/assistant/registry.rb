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

      def initialize(tool_classes = [])
        @tool_classes = tool_classes
      end

      # @param tool_class [Class<Spree::Assistant::Tool>]
      # @return [self]
      def <<(tool_class)
        @tool_classes << tool_class unless @tool_classes.include?(tool_class)
        self
      end
      alias add <<

      def each(&)
        @tool_classes.each(&)
      end

      # @return [Array<Class<Spree::Assistant::Tool>>]
      def to_a
        @tool_classes.dup
      end

      # @param name [String]
      # @return [Class<Spree::Assistant::Tool>, nil]
      def find_by_name(name)
        @tool_classes.find { |tool_class| tool_class.tool_name == name.to_s }
      end

      # Tools the given admin may actually use, instantiated for this context.
      # This is what the model is offered — a user without `write_products`
      # never learns that a price-changing tool exists.
      #
      # @param context [Spree::Assistant::Context]
      # @return [Array<Spree::Assistant::Tool>]
      def available_for(context)
        @tool_classes.map { |tool_class| tool_class.new(context) }.select(&:permitted?)
      end
    end
  end
end
