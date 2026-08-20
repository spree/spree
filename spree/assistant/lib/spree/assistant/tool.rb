module Spree
  module Assistant
    # One entry in the assistant's tool registry.
    #
    # A tool is a plain Spree object: a name, a description the model reads, a
    # JSON parameter schema, the permission key that gates it, whether it
    # mutates the store, and an executor. Nothing here knows which LLM library
    # runs the conversation — the RubyLLM classes are generated adapters
    # ({Spree::Assistant::ToolAdapter}), and a future MCP server is a second
    # adapter over this same registry.
    #
    # Subclasses implement {#call} and declare their metadata with the class-level
    # DSL:
    #
    #   class Spree::Assistant::Tools::SearchResources < Spree::Assistant::Tool
    #     tool_name 'search_resources'
    #     description 'Search store records.'
    #     permission 'read_products'
    #     param :resource, description: 'What to search', required: true
    #
    #     def call(resource:)
    #       # ...
    #     end
    #   end
    class Tool
      class << self
        # @return [String] the name the model calls this tool by
        def tool_name(value = nil)
          @tool_name = value if value
          @tool_name
        end

        # @return [String] what the tool does, read by the model when choosing
        def description(value = nil)
          @description = value if value
          @description
        end

        # RBAC permission key required to use this tool. A user without it never
        # sees the tool in the list handed to the model.
        #
        # @return [String]
        def permission(value = nil)
          @permission = value if value
          @permission
        end

        # Declares that this tool changes store data, so the turn halts for
        # human approval instead of executing.
        #
        # @return [void]
        def mutating!
          @mutating = true
        end

        # @return [Boolean]
        def mutating?
          @mutating == true
        end

        # @param name [Symbol]
        # @param type [Symbol] JSON schema type
        # @param description [String]
        # @param required [Boolean]
        # @return [void]
        def param(name, type: :string, description: nil, required: false)
          params[name] = { type: type, description: description, required: required }
        end

        # @return [Hash{Symbol => Hash}]
        def params
          @params ||= {}
        end
      end

      # @return [Spree::Assistant::Context] who is asking, and where
      attr_reader :context

      # @param context [Spree::Assistant::Context]
      def initialize(context)
        @context = context
      end

      delegate :tool_name, :description, :permission, :mutating?, :params, to: :class

      # Runs the tool. Subclasses implement this with keyword arguments matching
      # their declared params.
      #
      # @return [Hash] the result handed back to the model
      def call(**)
        raise NotImplementedError, 'Assistant tools must implement #call'
      end

      # One-line description of what approving this call would do, shown on the
      # approval card. Mutating tools should override it — the merchant reads
      # this, not the raw arguments.
      #
      # @param arguments [Hash]
      # @return [String]
      def summary(arguments)
        "#{tool_name} #{arguments.to_json}"
      end

      # Whether the asking user may use this tool at all.
      #
      # @return [Boolean]
      def permitted?
        context.permitted?(permission)
      end
    end
  end
end
