# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin Promotion serializer — adds operational fields the Store API
        # never exposes (multi-codes counts, usage stats, internal promotion
        # category, store assignments, timestamps).
        class PromotionSerializer < V3::PromotionSerializer
          typelize starts_at: [:string, nullable: true],
                   expires_at: [:string, nullable: true],
                   usage_limit: [:number, nullable: true],
                   match_policy: "'all' | 'any'",
                   path: [:string, nullable: true],
                   kind: "'coupon_code' | 'automatic'",
                   multi_codes: :boolean,
                   number_of_codes: [:number, nullable: true],
                   code_prefix: [:string, nullable: true],
                   promotion_category_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   action_ids: 'string[]',
                   rule_ids: 'string[]'

          attributes :starts_at, :expires_at, :usage_limit, :match_policy,
                     :path, :kind, :multi_codes, :number_of_codes, :code_prefix,
                     :promotion_category_id, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :action_ids do |promotion|
            promotion.promotion_actions.map(&:prefixed_id)
          end

          attribute :rule_ids do |promotion|
            promotion.promotion_rules.map(&:prefixed_id)
          end

          # The rows under the same names the write accepts, on request: a
          # reader holding only `rule_ids` cannot tell what a promotion does
          # without a request per rule.
          many :promotion_rules,
               key: :rules,
               resource: proc { Spree.api.admin_promotion_rule_serializer },
               if: proc { expand?('rules') }

          many :promotion_actions,
               key: :actions,
               resource: proc { Spree.api.admin_promotion_action_serializer },
               if: proc { expand?('actions') }
        end
      end
    end
  end
end
