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

      # One line saying what approving this call would do. It is the entire
      # approval card — the merchant decides on this sentence and nothing else,
      # so every mutating tool should override it with something that reads
      # like an instruction ("Set Blue Shirt to draft"), naming the record
      # rather than its id.
      #
      # The fallback spells the arguments out rather than dumping JSON, so a
      # tool that forgets to override is merely terse instead of unreadable.
      #
      # @param arguments [Hash]
      # @return [String]
      def summary(arguments)
        described = arguments.map { |key, value| "#{key.to_s.humanize.downcase} #{value}" }.join(', ')

        [tool_name.humanize, described.presence].compact.join(': ')
      end

      # Whether the asking user may use this tool at all.
      #
      # @return [Boolean]
      def permitted?
        context.permitted?(permission)
      end

      protected

      # Refuses unless this admin may take `action` on `record`.
      #
      # Holding `write_products` says an admin may edit products; it does not
      # say they may edit *this* one. A host app can narrow that with a
      # record-level rule, and the Admin API honours it — so any tool that
      # changes a record must ask here first. Returns an error the model reads
      # rather than raising, so the assistant explains itself instead of the
      # turn dying.
      #
      # @param action [Symbol]
      # @param record [Object]
      # @return [Hash, nil] an error result to return, or nil when allowed
      def unauthorized(action, record)
        return if context.can?(action, record)

        { error: "You do not have permission to #{action} this #{record.class.name.demodulize.underscore.humanize.downcase}." }
      end
    end
  end
end
