module Spree
  module Assistant
    # Records a mutation the model asked for but is not allowed to run yet.
    #
    # Writes the pair the conversation needs to stay valid: the assistant
    # message that made the call, and a placeholder tool result answering it.
    # Without the result the next turn would send a tool call nothing responded
    # to, which providers reject. Approval overwrites that placeholder with the
    # real outcome.
    class PersistProposal
      # @param chat [Spree::AssistantChat]
      # @param turn [Spree::Assistant::Turn]
      def initialize(chat:, turn:)
        @chat = chat
        @turn = turn
      end

      # @return [Spree::AssistantToolCall] the row now awaiting a decision
      def call
        proposal = turn.proposal
        tool = proposal[:tool]
        arguments = proposal[:arguments] || {}

        Spree::AssistantToolCall.transaction do
          call_message = chat.assistant_messages.create!(
            role: Spree::AssistantMessage::ASSISTANT,
            content: ''
          )

          tool_call = call_message.tool_calls.create!(
            tool_call_id: "call_#{SecureRandom.hex(8)}",
            name: tool.tool_name,
            arguments: arguments,
            summary: tool.summary(arguments),
            status: Spree::AssistantToolCall::PROPOSED
          )

          chat.assistant_messages.create!(
            role: Spree::AssistantMessage::TOOL,
            content: Spree::Assistant::AWAITING_APPROVAL_MARKER,
            tool_call: tool_call
          )

          tool_call
        end
      end

      private

      attr_reader :chat, :turn
    end
  end
end
