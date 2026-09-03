module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::SavedReport}: the reporting contract
        # query and its attribution.
        class SavedReportSerializer < V3::BaseSerializer
          typelize name: :string,
                   description: [:string, nullable: true],
                   query: 'Record<string, unknown>',
                   seeded: :boolean,
                   user_id: [:string, nullable: true],
                   author_name: [:string, nullable: true],
                   created_at: :string,
                   updated_at: :string

          attributes :name, :description, :query, :seeded, :created_at, :updated_at

          attribute :user_id do |report|
            report.user&.prefixed_id
          end

          attribute :author_name do |report|
            user = report.user
            next nil unless user

            user.full_name.presence || user.email
          end
        end
      end
    end
  end
end
