module Spree
  module Api
    module V3
      module Admin
        class AssistantChatSerializer < V3::BaseSerializer
          typelize title: [:string, nullable: true],
                   message_count: :number

          attributes :title, created_at: :iso8601, updated_at: :iso8601

          attribute :message_count do |chat|
            chat.assistant_messages.size
          end

          # Only when a single chat is opened — the history list stays cheap.
          many :assistant_messages,
               key: :messages,
               resource: proc { Spree::Api::V3::Admin::AssistantMessageSerializer },
               if: proc { params[:include_messages] }
        end
      end
    end
  end
end
