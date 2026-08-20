module Spree
  module Api
    module V3
      module Admin
        class AssistantMessageSerializer < V3::BaseSerializer
          typelize role: :string,
                   content: [:string, nullable: true]

          attributes :role, created_at: :iso8601

          # Tool-result rows are conversation plumbing, not something a merchant
          # reads — and while a change is held, the content is the
          # awaiting-approval placeholder. The approval card carries what the
          # merchant actually needs to see.
          attribute :content do |message|
            message.tool? ? nil : message.content
          end

          many :tool_calls, resource: proc { Spree::Api::V3::Admin::AssistantToolCallSerializer }
        end
      end
    end
  end
end
