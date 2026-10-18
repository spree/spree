module Spree
  module Api
    module V3
      module Admin
        module Assistant
          # Sends a message and streams the resulting turn.
          #
          # Server-sent events rather than a plain JSON response: a turn can take
          # a while, and a merchant watching an empty box wonders whether it
          # broke. The stream also carries tool activity, so the panel can show
          # what the assistant is doing while it does it.
          class MessagesController < BaseController
            include ActionController::Live

            before_action :require_assistant_permission!
            before_action :load_chat

            # POST /api/v3/admin/assistant/chats/:chat_id/messages
            def create
              start_stream!

              turn = Spree::Assistant::RunTurn.new(
                chat: @chat,
                context: assistant_context,
                message: params.require(:content),
                on_event: method(:write_event)
              ).call

              write_event(:'turn.finished', awaiting_approval: turn.awaiting_approval?)
            rescue Spree::Assistant::ProviderError => e
              write_event(:'turn.failed', message: e.message)
            rescue ActionController::Live::ClientDisconnected
              # The merchant closed the panel mid-turn; nothing to report.
              nil
            rescue StandardError => e
              Rails.logger.error("[Spree Assistant] turn failed: #{e.class}: #{e.message}")
              write_event(:'turn.failed', message: I18n.t('spree.assistant.errors.turn_failed'))
            ensure
              response.stream.close
            end

            private

            def start_stream!
              response.headers['Content-Type'] = 'text/event-stream'
              # Proxies that buffer would defeat the point of streaming.
              response.headers['Cache-Control'] = 'no-cache'
              response.headers['X-Accel-Buffering'] = 'no'
            end

            # One SSE frame. Payloads are Spree's own shapes — no LLM library
            # type reaches the wire.
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
