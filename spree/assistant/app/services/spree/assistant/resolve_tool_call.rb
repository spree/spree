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
      # @param context [Spree::AgentTools::Context]
      # @param approve [Boolean]
      def initialize(tool_call:, context:, approve:)
        @tool_call = tool_call
        @context = context
        @approve = approve
      end

      # @return [Spree::AssistantToolCall]
      def call
        claim!

        approve ? execute! : reject!
        tool_call
      end

      private

      attr_reader :tool_call, :context, :approve

      # Takes the decision atomically, before the tool runs.
      #
      # A read-then-act check let two concurrent approvals both pass and both
      # execute — one human approval producing two writes. Harmless for a status
      # change, but the approval gate's whole promise is that a merchant
      # authorises exactly one change, and the tools this gate is built for are
      # prices and refunds. The conditional UPDATE is the same pre-claim the
      # payment workflows use before touching a gateway: exactly one caller can
      # move the row out of `proposed`, and the loser is told it was already
      # decided.
      def claim!
        claimed = Spree::AssistantToolCall.
                  where(id: tool_call.id, status: Spree::AssistantToolCall::PROPOSED).
                  update_all(
                    status: approve ? Spree::AssistantToolCall::APPROVED : Spree::AssistantToolCall::REJECTED,
                    updated_at: Time.current
                  )

        raise AlreadyResolvedError if claimed.zero?

        # The in-memory copy predates the claim, so refresh it before anything
        # reads a status or writes alongside one.
        tool_call.reload
      end

      def execute!
        tool = build_tool

        # Re-checked at execution rather than trusted from proposal time: the
        # card may be approved minutes later, and the admin's roles can change
        # in between.
        unless tool.permitted?
          # Recorded before raising: the row is already claimed, so leaving it
          # `approved` would strand a change that never ran and can never be
          # decided again.
          finish(status: Spree::AssistantToolCall::FAILED,
                 result: { error: I18n.t('spree.assistant.errors.permission_lost') })
          raise ForbiddenError
        end

        result = tool.call(**tool_call.call_arguments)
        finish(status: Spree::AssistantToolCall::EXECUTED, result: result)
      rescue ForbiddenError, AlreadyResolvedError
        raise
      rescue StandardError => e
        # Recorded as the tool's result rather than re-raised: the turn then
        # continues and the assistant explains what went wrong. Raising here
        # would abort before the model ever saw the failure, leaving the
        # merchant with a generic "could not finish that" and an approval they
        # believe went through.
        Rails.logger.error("[Spree Assistant] tool #{tool_call.name} failed: #{e.class}: #{e.message}")
        finish(status: Spree::AssistantToolCall::FAILED, result: { error: e.message })
      end

      def reject!
        finish(
          status: Spree::AssistantToolCall::REJECTED,
          result: { declined: true, reason: I18n.t('spree.assistant.tool_calls.declined') }
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
        tool_class = Spree.admin_agent_tools.find { |candidate| candidate.tool_name == tool_call.name }
        raise UnknownToolError, tool_call.name if tool_class.nil?

        tool_class.new(context)
      end
    end
  end
end
