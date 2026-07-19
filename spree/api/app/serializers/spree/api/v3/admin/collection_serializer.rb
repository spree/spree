module Spree
  module Api
    module V3
      module Admin
        # Admin API Collection serializer — extends the customer-facing serializer
        # with the merchandising config (automatic / rules_match_policy / rules)
        # and back-office fields (metadata, timestamps, admin custom fields).
        class CollectionSerializer < V3::CollectionSerializer
          include Spree::Api::V3::Admin::Translatable

          typelize automatic: :boolean, rules_match_policy: :string,
                   metadata: 'Record<string, unknown>'

          attributes :automatic, :rules_match_policy, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          many :rules,
               resource: proc { Spree.api.admin_collection_rule_serializer }

          # Override inherited custom_fields to use the admin serializer.
          many :metafields,
               key: :custom_fields,
               resource: proc { Spree.api.admin_custom_field_serializer },
               if: proc { expand?('custom_fields') }
        end
      end
    end
  end
end
