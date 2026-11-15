module Spree
  module Assistant
    # The outcome of one assistant turn, in Spree's own vocabulary.
    #
    # This is the boundary the LLM library stops at: no RubyLLM type — not a
    # `ToolCall`, not a `Message` — travels past here into controllers,
    # serializers or the registry. That is what kept the 2.0 upgrade, which
    # deleted the halt mechanism the gate was first built on, a change to the
    # adapter and this file rather than to the whole gem.
    class Turn
      include ActiveModel::Model
      include ActiveModel::Attributes

      # @return [Spree::AssistantChat]
      attr_accessor :chat

      # @return [String, nil] the assistant's reply, when it produced one
      attr_accessor :text

      # @return [Spree::AssistantToolCall, nil] the mutation awaiting approval
      attr_accessor :pending_tool_call

      # @return [Array<Hash>] tool activity to show in the panel
      attr_reader :activity

      def initialize(chat: nil, **attributes)
        super(**attributes)
        @chat = chat
        @activity = []
        @proposal = nil
      end

      # Recorded by the tool adapter when a mutating tool is reached, instead of
      # executing it.
      #
      # Records a change the model wants approved.
      #
      # Only the first is kept. A model can ask for several changes in one
      # response, and showing one card for two held calls would let a merchant
      # approve one change believing they had approved both. Re-recording the
      # same call is a no-op, because the library treats an approval resolver
      # as an idempotent read and may consult it more than once per turn.
      #
      # @param tool [Spree::AgentTool]
      # @param arguments [Hash]
      # @param tool_call_id [String] the library's id for this call
      # @return [Boolean] whether this proposal was the one recorded
      def propose!(tool:, arguments:, tool_call_id: nil)
        return true if @proposal.present? && @proposal[:tool_call_id] == tool_call_id
        return false if @proposal.present?

        @proposal = { tool: tool, arguments: arguments, tool_call_id: tool_call_id }
        true
      end

      # @return [Hash, nil]
      attr_reader :proposal

      # @return [Boolean] whether the store is waiting on a human decision
      def awaiting_approval?
        pending_tool_call.present?
      end

      # @param entry [Hash]
      # @return [void]
      def record_activity(entry)
        @activity << entry
      end

      # A model that misreads a tool result can ask for the same lookup forever.
      # Nothing in the library bounds that, so the turn counts calls itself and
      # refuses past the limit — the model is told to answer with what it has.
      MAX_TOOL_CALLS = 12

      # The call being checked has already been recorded by `before_tool_call`,
      # so the comparison allows for it — otherwise the budget cuts one call
      # short of what it advertises.
      #
      # @return [Boolean] whether another tool call is still allowed
      def tool_budget_available?
        @activity.size <= MAX_TOOL_CALLS
      end
    end
  end
end
