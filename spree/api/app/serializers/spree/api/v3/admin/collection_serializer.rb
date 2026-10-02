module Spree
  module Api
    module V3
      module Admin
        # Admin API Collection serializer — extends the customer-facing serializer
        # with the merchandising config (automatic / rules_match_policy / rules)
        # and back-office fields (metadata, timestamps, admin custom fields).
        class CollectionSerializer < V3::CollectionSerializer
          include Spree::Api::V3::Admin::Translatable

          typelize automatic: :boolean, rules_match_policy: [:string, enum: Spree::Collection::RULES_MATCH_POLICIES],
                   metadata: 'Record<string, unknown>'

          attributes :automatic, :rules_match_policy, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          expandable :many, :rules, :admin_collection_rule_serializer

          # Override inherited custom_fields to use the admin serializer.
          expandable :many, :custom_fields, :admin_custom_field_serializer
        end
      end
    end
  end
end
