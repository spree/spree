module Spree
  module Api
    module V3
      module Admin
        # A change the assistant wants to make, and what became of it.
        #
        # Both the merchant-readable summary and the exact arguments are
        # exposed: the summary is what the approval card leads with, and the
        # arguments are what a cautious merchant expands to check before saying
        # yes.
        class AssistantToolCallSerializer < V3::BaseSerializer
          typelize name: :string,
                   status: [:string, nullable: true],
                   summary: [:string, nullable: true],
                   arguments: 'Record<string, unknown>',
                   result: 'Record<string, unknown> | null',
                   awaiting_approval: :boolean

          attributes :name, :status, :summary, :arguments,
                     created_at: :iso8601, resolved_at: :iso8601

          attribute :awaiting_approval do |tool_call|
            tool_call.awaiting_approval?
          end

          # Withheld while a decision is outstanding — there is no result yet,
          # and the placeholder is an implementation detail.
          attribute :result do |tool_call|
            tool_call.awaiting_approval? ? nil : tool_call.result
          end
        end
      end
    end
  end
end
