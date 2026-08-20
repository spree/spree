module Spree
  module Assistant
    # Turns a {Spree::Assistant::Tool} into the class shape RubyLLM expects.
    #
    # This is the ONLY place that knows how the LLM library models tools, which
    # is what keeps the registry reusable and the eventual RubyLLM 2.0 upgrade a
    # one-file change: 2.0 removes `Tool::Halt` in favour of a first-class
    # `requires_approval`, and nothing outside this file may hold either.
    #
    # A mutating tool never executes here. It records the proposal on the turn
    # and halts, so the loop stops with the store untouched and the merchant
    # gets an approval card. Approval executes the tool through
    # {Spree::Assistant::ExecuteToolCall} instead.
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
        # @param turn [Spree::Assistant::Turn] collects the halted proposal
        # @return [RubyLLM::Tool]
        def build(tool, turn)
          type_map = TYPE_MAP

          Class.new(::RubyLLM::Tool) do
            description tool.description

            tool.params.each do |param_name, options|
              param param_name,
                    type: type_map.fetch(options[:type], 'string'),
                    desc: options[:description],
                    required: options[:required]
            end

            define_method(:name) { tool.tool_name }

            define_method(:execute) do |**arguments|
              # Refused rather than raised: the model reads this as a result and
              # answers with what it already has, instead of the turn dying.
              unless turn.tool_budget_available?
                next { error: 'Tool call limit reached for this turn. Answer with the information you already have.' }
              end

              if tool.mutating?
                turn.propose!(tool: tool, arguments: arguments)
                # Persisted as this call's tool result, so the conversation stays
                # valid; approval overwrites it with the real outcome.
                halt(Spree::Assistant::AWAITING_APPROVAL_MARKER)
              else
                tool.call(**arguments)
              end
            end
          end.new
        end
      end
    end
  end
end
