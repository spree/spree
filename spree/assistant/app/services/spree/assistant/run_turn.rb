module Spree
  module Assistant
    # Runs one turn of a conversation.
    #
    # The conversation is rebuilt from the persisted rows on every turn, which
    # is what makes the approval gate work: approving a held mutation rewrites
    # its tool-result row and runs another turn, and the model sees the real
    # outcome in the slot it expects. Replaying explicitly (rather than trusting
    # an in-memory chat) is deliberate — a stale replay would re-send the
    # awaiting-approval placeholder and the model would confidently report work
    # that never happened.
    class RunTurn
      # @param chat [Spree::AssistantChat]
      # @param context [Spree::Assistant::Context]
      # @param message [String, nil] a new merchant message, or nil to continue
      # @param on_event [Proc, nil] receives streamed events for the SSE endpoint
      def initialize(chat:, context:, message: nil, on_event: nil)
        @chat = chat
        @context = context
        @message = message
        @on_event = on_event
      end

      # @return [Spree::Assistant::Turn]
      def call
        turn = Turn.new(chat: chat)

        persist_user_message! if message.present?

        llm_chat = build_llm_chat(turn)
        replay_into(llm_chat)
        reply = llm_chat.complete

        finish(turn, reply)
      rescue Spree::Assistant::ProviderError => e
        emit(:'turn.failed', message: e.message)
        raise
      end

      private

      attr_reader :chat, :context, :message, :on_event

      def persist_user_message!
        chat.assistant_messages.create!(role: Spree::AssistantMessage::USER, content: message)
        chat.title_from!(message)
      end

      def build_llm_chat(turn)
        credentials = Spree::Assistant::ResolveProvider.new(store: context.store).call
        raise Spree::Assistant::ProviderError, Spree.t('assistant.errors.not_configured') if credentials.nil?

        llm_chat = ChatBuilder.build(
          provider_key: credentials[:provider],
          api_key: credentials[:api_key],
          model: credentials[:model]
        )

        llm_chat.with_instructions(SystemPrompt.new(context: context).to_s)

        tools = Spree::Assistant.tools.available_for(context)
        adapters = tools.map { |tool| ToolAdapter.build(tool, turn) }
        llm_chat.with_tools(*adapters) if adapters.any?

        instrument(llm_chat, turn, tools)
        llm_chat
      end

      # Streams text to the panel and records tool activity as it happens.
      def instrument(llm_chat, turn, tools)
        by_name = tools.index_by(&:tool_name)

        llm_chat.before_tool_call do |tool_call|
          tool = by_name[tool_call.name.to_s]
          turn.record_activity(name: tool_call.name, arguments: tool_call.arguments)
          emit(:'tool_call.started',
               name: tool_call.name,
               summary: tool&.summary(tool_call.arguments.symbolize_keys),
               mutating: tool&.mutating? || false)
        end
      end

      # Loads the conversation as it now stands in the database. Read fresh on
      # every turn — never from a cached association — so an approved mutation's
      # real result reaches the model instead of the placeholder it replaced.
      def replay_into(llm_chat)
        chat.assistant_messages.reload.for_replay.each do |record|
          llm_chat.add_message(
            role: record.role.to_sym,
            content: record.content.to_s,
            tool_call_id: record.tool_call&.tool_call_id,
            tool_calls: llm_tool_calls_for(record)
          )
        end
      end

      # Keyed by call id, which is how the library indexes them.
      def llm_tool_calls_for(record)
        calls = record.tool_calls.to_a
        return nil if calls.empty?

        calls.to_h do |call|
          [call.tool_call_id,
           ::RubyLLM::ToolCall.new(id: call.tool_call_id, name: call.name, arguments: call.arguments || {})]
        end
      end

      # `reply` is the library's return value and is polymorphic: a message when
      # the turn ran to completion, a halt marker when a mutation stopped it.
      # Both are unwrapped here so nothing downstream ever sees a library type.
      def finish(turn, reply)
        if turn.proposal.present?
          turn.pending_tool_call = PersistProposal.new(chat: chat, turn: turn).call
          emit(:'tool_call.proposed', tool_call: turn.pending_tool_call)
        else
          turn.text = reply.respond_to?(:content) ? reply.content.to_s : reply.to_s
          persist_assistant_message!(reply, turn.text)
          emit(:'message.completed', text: turn.text)
        end

        turn
      end

      def persist_assistant_message!(reply, text)
        chat.assistant_messages.create!(
          role: Spree::AssistantMessage::ASSISTANT,
          content: text,
          input_tokens: reply.try(:input_tokens),
          output_tokens: reply.try(:output_tokens)
        )
      end

      def emit(event, **payload)
        on_event&.call(event, payload)
      end
    end
  end
end
