module Spree
  module Assistant
    # Applies a merchant's decision on a held mutation.
    #
    # Approving runs the tool for real and rewrites its placeholder result;
    # rejecting records the refusal in the same slot. Either way the
    # conversation is left valid and the caller runs another turn, so the model
    # learns what happened and can answer.
    class ResolveToolCall
      # @param tool_call [Spree::AssistantToolCall]
      # @param context [Spree::Assistant::Context]
      # @param approve [Boolean]
      def initialize(tool_call:, context:, approve:)
        @tool_call = tool_call
        @context = context
        @approve = approve
      end

      # @return [Spree::AssistantToolCall]
      def call
        raise AlreadyResolvedError unless tool_call.awaiting_approval?

        approve ? execute! : reject!
        tool_call
      end

      private

      attr_reader :tool_call, :context, :approve

      def execute!
        tool = build_tool

        # Re-checked at execution rather than trusted from proposal time: the
        # card may be approved minutes later, and the admin's roles can change
        # in between.
        raise ForbiddenError unless tool.permitted?

        result = tool.call(**tool_call.call_arguments)
        finish(status: Spree::AssistantToolCall::EXECUTED, result: result)
      rescue ForbiddenError, AlreadyResolvedError
        raise
      rescue StandardError => e
        # The model is told the tool failed so it can explain itself, rather
        # than the turn dying and the merchant seeing nothing.
        finish(status: Spree::AssistantToolCall::FAILED, result: { error: e.message })
        raise
      end

      def reject!
        finish(
          status: Spree::AssistantToolCall::REJECTED,
          result: { declined: true, reason: Spree.t('assistant.tool_calls.declined') }
        )
      end

      def finish(status:, result:)
        Spree::AssistantToolCall.transaction do
          tool_call.update!(
            status: status,
            result: result,
            resolved_at: Time.current,
            resolved_by: context.user
          )
          # Overwrites the awaiting-approval placeholder in place, so the model
          # sees the outcome where it expects this call's answer.
          tool_call.result_message&.update!(content: result.to_json)
        end
      end

      def build_tool
        tool_class = Spree::Assistant.tools.find_by_name(tool_call.name)
        raise UnknownToolError, tool_call.name if tool_class.nil?

        tool_class.new(context)
      end
    end
  end
end
