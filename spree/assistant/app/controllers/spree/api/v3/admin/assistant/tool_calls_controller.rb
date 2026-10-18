module Spree
  module Api
    module V3
      module Admin
        module Assistant
          # The merchant's decision on a held change.
          #
          # Approving runs the tool and streams the continued conversation, so
          # the merchant sees the assistant confirm what it did rather than
          # having to ask.
          class ToolCallsController < BaseController
            include ActionController::Live

            before_action :require_assistant_permission!
            before_action :load_chat
            before_action :load_tool_call

            # POST /api/v3/admin/assistant/chats/:chat_id/tool_calls/:id/approve
            def approve
              resolve_and_continue(approve: true)
            end

            # POST /api/v3/admin/assistant/chats/:chat_id/tool_calls/:id/reject
            def reject
              resolve_and_continue(approve: false)
            end

            private

            def resolve_and_continue(approve:)
              start_stream!

              tool_call = Spree::Assistant::ResolveToolCall.new(
                tool_call: @tool_call,
                context: assistant_context,
                approve: approve
              ).call

              write_event(:'tool_call.resolved', tool_call: tool_call)

              # No new merchant message: the turn continues from the decision,
              # and the model reads the real outcome where the placeholder was.
              turn = Spree::Assistant::RunTurn.new(
                chat: @chat,
                context: assistant_context,
                on_event: method(:write_event)
              ).call

              write_event(:'turn.finished', awaiting_approval: turn.awaiting_approval?)
            rescue Spree::Assistant::ForbiddenError
              write_event(:'turn.failed', message: I18n.t('spree.assistant.errors.permission_lost'))
            rescue Spree::Assistant::AlreadyResolvedError
              write_event(:'turn.failed', message: I18n.t('spree.assistant.errors.already_resolved'))
            rescue ActionController::Live::ClientDisconnected
              nil
            rescue StandardError => e
              Rails.logger.error("[Spree Assistant] resolve failed: #{e.class}: #{e.message}")
              write_event(:'turn.failed', message: I18n.t('spree.assistant.errors.turn_failed'))
            ensure
              response.stream.close
            end

            def start_stream!
              response.headers['Content-Type'] = 'text/event-stream'
              response.headers['Cache-Control'] = 'no-cache'
              response.headers['X-Accel-Buffering'] = 'no'
            end

            def write_event(event, payload = {})
              response.stream.write("event: #{event}\n")
              response.stream.write("data: #{serialize_payload(payload).to_json}\n\n")
            end

            def serialize_payload(payload)
              payload.transform_values do |value|
                if value.is_a?(Spree::AssistantToolCall)
                  Spree::Api::V3::Admin::AssistantToolCallSerializer.new(value).to_h
                else
                  value
                end
              end
            end

            def load_chat
              @chat = chats_scope.find_by_prefix_id!(params[:chat_id])
            end

            # Scoped through the chat, so a call id from someone else's
            # conversation is a 404 rather than an approval.
            def load_tool_call
              @tool_call = Spree::AssistantToolCall
                           .joins(:message)
                           .where(spree_assistant_messages: { chat_id: @chat.id })
                           .find_by_prefix_id!(params[:id])
            end

            def require_assistant_permission!
              return if assistant_context.permitted?('read_assistant')

              render json: { error: I18n.t('spree.assistant.errors.forbidden') }, status: :forbidden
            end
          end
        end
      end
    end
  end
end
