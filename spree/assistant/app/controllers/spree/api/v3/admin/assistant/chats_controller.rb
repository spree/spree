module Spree
  module Api
    module V3
      module Admin
        module Assistant
          # The merchant's own conversations.
          class ChatsController < BaseController
            before_action :require_assistant_permission!
            before_action :load_chat, only: %i[show destroy]

            # GET /api/v3/admin/assistant/chats
            def index
              # Counted in one query rather than one per chat.
              chats = chats_scope.recent_first.limit(50).includes(:assistant_messages)

              render json: { data: chats.map { |chat| serialize(chat) } }
            end

            # POST /api/v3/admin/assistant/chats
            def create
              chat = Spree::AssistantChat.create!(
                store: current_store,
                admin_user: current_user
              )

              render json: { data: serialize(chat) }, status: :created
            end

            # GET /api/v3/admin/assistant/chats/:id
            def show
              render json: { data: serialize(@chat, include_messages: true) }
            end

            # DELETE /api/v3/admin/assistant/chats/:id
            def destroy
              @chat.destroy!

              head :no_content
            end

            private

            def load_chat
              @chat = chats_scope.find_by_prefix_id!(params[:id])
            end

            def require_assistant_permission!
              return if assistant_context.permitted?('read_assistant')

              render json: { error: I18n.t('spree.assistant.errors.forbidden') }, status: :forbidden
            end

            def serialize(chat, include_messages: false)
              Spree::Api::V3::Admin::AssistantChatSerializer.new(
                chat,
                params: { include_messages: include_messages }
              ).to_h
            end
          end
        end
      end
    end
  end
end
