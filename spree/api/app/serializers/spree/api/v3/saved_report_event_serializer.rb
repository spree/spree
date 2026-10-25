module Spree
  module Api
    module V3
      # The event shape for `saved_report.*`: the saved query and who owns it,
      # without the author's name or email, which webhook payloads never carry.
      class SavedReportEventSerializer < BaseSerializer
        typelize name: :string,
                 description: [:string, nullable: true],
                 query: 'Record<string, unknown>',
                 seeded: :boolean,
                 user_id: [:string, nullable: true],
                 created_at: :string,
                 updated_at: :string

        attributes :name, :description, :query, :seeded, :created_at, :updated_at

        attribute :user_id do |report|
          report.user&.prefixed_id
        end
      end
    end
  end
end
