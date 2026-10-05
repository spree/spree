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
            # An array must say what it holds: a client validating arguments
            # against the schema refuses the call otherwise.
            property[:items] = { type: json_type(options[:items] || :string) } if property[:type] == 'array'

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
        #
        # The payload itself is NOT repeated here: it already travels as
        # structured content, and a client that renders both would put every
        # record into the model's context twice — on exactly the results the
        # design requires to stay compact. Without a summary this says what
        # came back, and the structured half carries it.
        # What the model reads.
        #
        # A client may render the structured half, the text half, or both —
        # the protocol does not say — so the text has to carry the answer
        # rather than point at it. Naming the keys and trusting the client to
        # look elsewhere leaves a model with nothing to work from.
        #
        # The exception is a list of records: those already carry a summary
        # line, and repeating every row would put the payload into the
        # model's context twice on exactly the results meant to stay compact.
        def text_for(result)
          return result.to_s unless result.is_a?(Hash)

          summary = result[:summary].presence
          return summary if summary
          return describe(result) if record_list?(result)

          JSON.generate(result)
        end

        # A page of records the caller can fetch individually.
        #
        # Only `records` counts. A report's rows look similar but are
        # computed figures that exist nowhere else — summarising them as
        # "returned 2 results" hands the model a row count where it asked
        # for the numbers.
        def record_list?(result)
          result.key?(:records)
        end

        # A sentence about a payload that carries no summary of its own: what
        # it holds, so the model knows whether to read the structured content
        # rather than having to.
        def describe(result)
          count = result[:count] || result[:row_count] || Array(result[:records] || result[:rows]).size
          total = result[:total]

          if total && count
            "Found #{total} #{'match'.pluralize(total)}#{", returning #{count}" if total != count}."
          elsif count.to_i.positive?
            "Returned #{count} #{'result'.pluralize(count)}."
          else
            "Returned #{result.keys.map(&:to_s).to_sentence}."
          end
        end
      end
    end
  end
end
