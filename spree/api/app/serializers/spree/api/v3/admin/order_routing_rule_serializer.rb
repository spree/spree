# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::OrderRoutingRule (and its STI subclasses) for the
        # per-channel routing-rules editor. Same shape as PromotionRule so the
        # frontend renders both with the same schema-driven preference form.
        class OrderRoutingRuleSerializer < BaseSerializer
          typelize type: :string,
                   channel_id: :string,
                   position: :number,
                   active: :boolean,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>",
                   label: :string,
                   description: :string

          attributes :position, :active
          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :channel_id do |rule|
            rule.channel&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          attribute :label, &:human_name
          attribute :description, &:human_description
        end
      end
    end
  end
end
