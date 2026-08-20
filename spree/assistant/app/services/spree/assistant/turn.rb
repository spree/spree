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
      # @param tool [Spree::Assistant::Tool]
      # @param arguments [Hash]
      # @return [void]
      def propose!(tool:, arguments:)
        @proposal = { tool: tool, arguments: arguments }
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
    end
  end
end
