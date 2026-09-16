module Spree
  module Mcp
    # Turns a {Spree::AgentTool} into an `MCP::Tool` the protocol can offer.
    #
    # The whole adapter: a name, a description, the tool's parameter schema as
    # JSON Schema, and a handler that runs the tool and shapes what comes back.
    # Nothing about a tool is written twice — a tool registered by an extension
    # is offered over MCP with no MCP code anywhere near it.
    module ToolAdapter
      class << self
        # @param tool [Spree::AgentTool] instantiated for the caller's context
        # @return [Class<MCP::Tool>]
        def build(tool)
          # The block is instance_exec'd on the generated tool class, so it
          # cannot call back into this module by name — `adapter` closes over
          # it instead.
          adapter = self

          ::MCP::Tool.define(
            name: tool.tool_name,
            description: tool.description,
            input_schema: input_schema(tool),
            annotations: annotations(tool)
          ) { |**arguments| adapter.respond(tool, arguments) }
        end

        # The tool's declared params as JSON Schema.
        #
        # @param tool [Spree::AgentTool]
        # @return [Hash]
        def input_schema(tool)
          properties = tool.params.to_h do |name, options|
            property = { type: json_type(options[:type]) }
            property[:description] = options[:description] if options[:description].present?
            property[:items] = { type: 'object' } if property[:type] == 'array'

            [name.to_s, property]
          end

          {
            type: 'object',
            properties: properties,
            required: tool.params.select { |_name, options| options[:required] }.keys.map(&:to_s)
          }
        end

        # Clients that gate confirmation on annotations rather than on a
        # server's word need both hints set explicitly: the gem defaults
        # `destructiveHint` to true, so a read tool that says nothing would be
        # confirmed like a deletion.
        #
        # @return [Hash]
        def annotations(tool)
          { read_only_hint: !tool.mutating?, destructive_hint: tool.mutating?, idempotent_hint: !tool.mutating? }
        end

        # A tool answers with a plain hash. A hash carrying `:error` is the
        # tool refusing — the model should read it and correct itself, so it
        # comes back as a tool error rather than a protocol error, which the
        # model never sees.
        #
        # Public because the definition block calls it through a closure.
        #
        # @param tool [Spree::AgentTool]
        # @param arguments [Hash]
        # @return [MCP::Tool::Response]
        def respond(tool, arguments)
          result = tool.call(**arguments.symbolize_keys.except(:server_context))

          if result.is_a?(Hash) && result[:error].present?
            ::MCP::Tool::Response.new([{ type: 'text', text: result[:error].to_s }], error: true)
          else
            ::MCP::Tool::Response.new([{ type: 'text', text: text_for(result) }], structured_content: result)
          end
        rescue ArgumentError => e
          # A missing or unknown keyword means the model filled the schema in
          # wrongly; naming the parameter lets it retry correctly.
          ::MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
        end

        private

        # A tool declares Ruby-ish types; JSON Schema wants its own names, and
        # anything unrecognised is a string, which every client can render.
        def json_type(type)
          case type&.to_sym
          when :boolean then 'boolean'
          when :integer then 'integer'
          when :number, :float, :decimal then 'number'
          when :object, :hash then 'object'
          when :array then 'array'
          else 'string'
          end
        end

        # A line the client can show beside its confirmation prompt, and the
        # model can read without parsing the structured payload.
        def text_for(result)
          return result.to_s unless result.is_a?(Hash)

          result[:summary].presence || JSON.generate(result)
        end
      end
    end
  end
end
