module Spree
  module Assistant
    # The outcome of one assistant turn, in Spree's own vocabulary.
    #
    # This is the boundary the LLM library stops at: no RubyLLM type — not
    # `Tool::Halt`, not the polymorphic `ask` return, not `RubyLLM::Message` —
    # travels past here into controllers, serializers or the registry. That is
    # what keeps the eventual RubyLLM 2.0 upgrade (which deletes the halt
    # mechanism) a one-file change.
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
      # Only the first is kept. Every tool call in a response runs before the
      # halt takes effect, so a request like "archive both of these" would
      # otherwise overwrite the first proposal and show one card — and the
      # merchant would approve one change believing they had approved both.
      # The rest are refused, and the model is told to ask again once this one
      # is decided.
      #
      # @param tool [Spree::Assistant::Tool]
      # @param arguments [Hash]
      # @return [Boolean] whether this proposal was the one recorded
      def propose!(tool:, arguments:)
        return false if @proposal.present?

        @proposal = { tool: tool, arguments: arguments }
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

      # @return [Boolean] whether another tool call is still allowed
      def tool_budget_available?
        @activity.size < MAX_TOOL_CALLS
      end
    end
  end
end
