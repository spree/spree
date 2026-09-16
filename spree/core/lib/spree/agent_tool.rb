module Spree
  # One entry in the agent-tool registry ({Spree.agent_tools}).
  #
  # A tool is a plain Spree object: a name, a description the model reads, a
  # JSON parameter schema, the permission key that gates it, whether it
  # mutates the store, and an executor. Nothing here knows which client is
  # asking — the MCP server and the dashboard assistant are both adapters
  # over this one registry, so a tool registered once is offered by both.
  #
  # Subclasses implement {#call} and declare their metadata with the class-level
  # DSL:
  #
  #   class Spree::AgentTools::SearchResources < Spree::AgentTool
  #     tool_name 'search_resources'
  #     description 'Search store records.'
  #     permission 'read_products'
  #     param :resource, description: 'What to search', required: true
  #
  #     def call(resource:)
  #       # ...
  #     end
  #   end
class AgentTool
    # Declarations live in class attributes rather than plain class-level
    # instance variables so a subclass inherits them. Subclassing a tool to
    # tweak it is the documented extension path, and with bare ivars the
    # subclass would come back `mutating? == false` — writing to the store
    # immediately, with no approval card, no permission gate and no argument
    # validation. Inheritance here is a safety property, not a convenience.
    class_attribute :declared_tool_name, instance_accessor: false
    class_attribute :declared_description, instance_accessor: false
    class_attribute :declared_permission, instance_accessor: false
    class_attribute :declared_mutating, instance_accessor: false, default: false
    class_attribute :declared_params, instance_accessor: false, default: {}.freeze

    class << self
      # @return [String] the name the model calls this tool by
      def tool_name(value = nil)
        self.declared_tool_name = value if value
        declared_tool_name
      end

      # @return [String] what the tool does, read by the model when choosing
      def description(value = nil)
        self.declared_description = value if value
        declared_description
      end

      # RBAC permission key required to use this tool. A user without it never
      # sees the tool in the list handed to the model.
      #
      # @return [String]
      def permission(value = nil)
        self.declared_permission = value if value
        declared_permission
      end

      # Declares that this tool changes store data, so the turn halts for
      # human approval instead of executing.
      #
      # @return [void]
      def mutating!
        self.declared_mutating = true
      end

      # @return [Boolean]
      def mutating?
        declared_mutating == true
      end

      # @param name [Symbol]
      # @param type [Symbol] JSON schema type
      # @param description [String]
      # @param required [Boolean]
      # @return [void]
      def param(name, type: :string, description: nil, required: false)
        # Reassigned rather than mutated, so declaring a param on a subclass
        # does not reach back and change the parent's list.
        self.declared_params = declared_params.merge(
          name => { type: type, description: description, required: required }
        ).freeze
      end

      # @return [Hash{Symbol => Hash}]
      def params
        declared_params
      end
    end

    # @return [Spree::AgentTools::Context] who is asking, and where
    attr_reader :context

    # @param context [Spree::AgentTools::Context]
    def initialize(context)
      @context = context
    end

    delegate :tool_name, :description, :permission, :mutating?, :params, to: :class

    # Runs the tool. Subclasses implement this with keyword arguments matching
    # their declared params.
    #
    # @return [Hash] the result handed back to the model
    def call(**)
      raise NotImplementedError, 'Agent tools must implement #call'
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
