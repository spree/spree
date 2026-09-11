module Spree
  module Assistant
    # Turns a {Spree::Assistant::Tool} into the class shape RubyLLM expects.
    #
    # This is the ONLY place that knows how the LLM library models tools, which
    # is what keeps the registry reusable and a library upgrade a one-file
    # change — the promise this file made under 1.x and kept at 2.0.
    #
    # A mutating tool never executes during a turn. It declares
    # `requires_approval`, so the library stops the loop with the call pending
    # and the store untouched, and the merchant gets an approval card. Approval
    # runs the tool through {Spree::Assistant::ResolveToolCall} in a later
    # request, against a context built fresh from that request's signed-in
    # admin — which is why the resolver here always answers "still pending"
    # rather than consulting a decision recorded elsewhere.
    class ToolAdapter
      TYPE_MAP = {
        string: 'string',
        integer: 'integer',
        number: 'number',
        boolean: 'boolean',
        array: 'array',
        object: 'object'
      }.freeze

      class << self
        # @param tool [Spree::Assistant::Tool]
        # @param turn [Spree::Assistant::Turn] collects the held proposal
        # @return [RubyLLM::Tool]
        def build(tool, turn)
          type_map = TYPE_MAP

          Class.new(::RubyLLM::Tool) do
            description tool.description

            tool.params.each do |param_name, options|
              parameter param_name,
                        type: type_map.fetch(options[:type], 'string'),
                        description: options[:description],
                        required: options[:required]
            end

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
      end
    end
  end
end
