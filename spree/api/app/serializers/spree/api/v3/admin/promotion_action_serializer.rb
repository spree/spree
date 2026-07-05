# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PromotionAction (and its STI subclasses) for the
        # admin promotion editor. The shape is intentionally generic so a
        # single component can render any subclass — `preferences` is the
        # current value hash, `preference_schema` describes its fields.
        class PromotionActionSerializer < BaseSerializer
          typelize type: :string,
                   promotion_id: :string,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>",
                   label: :string,
                   calculator: "{ type: string; label: string; preferences: Record<string, unknown>; preference_schema: Array<{ key: string; type: string; default: unknown }> } | null",
                   line_items: 'Array<{ variant_id: string; quantity: number }> | null'

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |action|
            action.class.api_type
          end

          attribute :promotion_id do |action|
            action.promotion&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          attribute :label do |action|
            action.respond_to?(:human_name) ? action.human_name : action.type.to_s.demodulize
          end

          # Calculator is exposed as a nested object so the SPA can render
          # the calculator picker + its own preference fields. Null for
          # actions that don't include CalculatedAdjustments. The SPA
          # formats the row summary itself off `label` + `preferences` —
          # see the action-summary helper in the admin promotion editor.
          attribute :calculator do |action|
            next nil unless action.respond_to?(:calculator) && action.calculator

            calc = action.calculator
            {
              type: calc.class.api_type,
              label: calc.class.respond_to?(:description) ? calc.class.description : calc.class.to_s.demodulize.titleize,
              preferences: calc.serialized_preferences,
              preference_schema: calc.serialized_preference_schema
            }
          end

          # Line items the action will add for CreateLineItems. variant_id
          # is prefixed for consistency with the rest of the API. Null on
          # actions that don't have the association.
          attribute :line_items do |action|
            next nil unless action.respond_to?(:promotion_action_line_items)

            action.promotion_action_line_items.map do |item|
              {
                variant_id: item.variant&.prefixed_id,
                quantity: item.quantity
              }
            end
          end
        end
      end
    end
  end
end
