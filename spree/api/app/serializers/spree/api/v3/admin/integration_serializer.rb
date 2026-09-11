module Spree
  module Api
    module V3
      module Admin
        # Admin-only — credentials never have a storefront surface. Secrets
        # are `:password` preferences, masked by `serialized_preferences`.
        class IntegrationSerializer < V3::BaseSerializer
          typelize type: [:string, comment: 'Integration type, registered by the provider gem that owns it (for example the EasyPost provider). Core ships none.'],
                   name: :string,
                   group: [:string, nullable: true],
                   active: :boolean,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown; choices?: string[] }>"

          attributes :name, :active,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :type do |integration|
            integration.class.api_type
          end

          attribute :group do |integration|
            integration.class.integration_group
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema
        end
      end
    end
  end
end
