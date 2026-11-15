module Spree
  module Assistant
    # Turns a {Spree::AgentTool} into the class shape RubyLLM expects.
    #
    # This is the ONLY place that knows how the LLM library models tools. The
    # tools themselves are core's registry ({Spree.admin_agent_tools}), the
    # same one the MCP server offers, so a tool registered once reaches both.
    #
    # A mutating tool never executes during a turn. It declares
    # `requires_approval`, so the library stops the loop with the call pending
    # and the store untouched, and the merchant gets an approval card. Approval
    # runs the tool through {Spree::Assistant::ResolveToolCall} in a later
    # request, against a context built fresh from that request's signed-in
    # admin — which is why the resolver here always answers "still pending"
    # rather than consulting a decision recorded elsewhere.
    class ToolAdapter
      class << self
        # @param tool [Spree::AgentTool] instantiated for the asking admin
        # @param turn [Spree::Assistant::Turn] collects the held proposal
        # @return [RubyLLM::Tool]
        def build(tool, turn)
          schema = parameters_schema(tool)

          Class.new(::RubyLLM::Tool) do
            description tool.description
            parameters schema if schema

            define_method(:name) { tool.tool_name }

            if tool.mutating?
              # No decision is ever recorded on this chat: the turn that
              # proposes a change and the request that approves it are
              # different HTTP requests with different chat objects. Answering
              # `nil` keeps the call pending, which is what stops the loop.
              #
              # The library documents resolvers as idempotent reads and may call
              # this more than once per turn, so recording the proposal is
              # guarded to keep the first one only.
              requires_approval do |tool_call|
                turn.propose!(tool: tool, arguments: (tool_call.arguments || {}).symbolize_keys,
                              tool_call_id: tool_call.id)
                nil
              end
            end

            define_method(:execute) do |**arguments|
              # Every problem below is returned as a result, never raised: the
              # model reads it, corrects itself and carries on. Raising would
              # abort the turn and leave the merchant with a generic failure.
              unless turn.tool_budget_available?
                next { error: 'Tool call limit reached for this turn. Answer with the information you already have.' }
              end

              # The library skips its own argument checking here, because this
              # `execute` accepts bare keywords and its validator reads the
              # method signature. Without this, a missing or invented argument
              # reaches the tool and raises ArgumentError out of the turn.
              missing = tool.params.filter_map do |param_name, options|
                param_name if options[:required] && arguments[param_name].blank?
              end
              next { error: "Missing required argument(s): #{missing.join(', ')}" } if missing.any?

              unknown = arguments.keys - tool.params.keys
              next { error: "Unknown argument(s): #{unknown.join(', ')}" } if unknown.any?

              tool.call(**arguments)
            end
          end.new
        end

        # The tool's declared params as JSON Schema.
        #
        # Written out rather than declared one `parameter` at a time, because
        # the library's own builder says every array holds strings — and a
        # stock update's rows or a report's filters are lists of objects, which
        # a vendor validating arguments against the schema would then refuse.
        #
        # @param tool [Spree::AgentTool]
        # @return [Hash, nil]
        def parameters_schema(tool)
          return if tool.params.empty?

          properties = tool.params.to_h do |param_name, options|
            property = { type: json_type(options[:type]), description: options[:description] }.compact
            property[:items] = { type: json_type(options[:items]) } if property[:type] == 'array'

            [param_name.to_s, property]
          end

          {
            type: 'object',
            properties: properties,
            required: tool.params.select { |_name, options| options[:required] }.keys.map(&:to_s)
          }
        end

        private

        def json_type(type)
          case type&.to_sym
          when :integer then 'integer'
          when :number, :float, :decimal then 'number'
          when :boolean then 'boolean'
          when :array then 'array'
          when :object, :hash then 'object'
          else 'string'
          end
        end
      end
    end
  end
end
