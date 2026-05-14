# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PromotionRule (and its STI subclasses) for the
        # admin promotion editor. Same shape as PromotionAction so the
        # frontend renders both with the same generic component.
        class PromotionRuleSerializer < BaseSerializer
          typelize type: :string,
                   promotion_id: :string,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>",
                   label: :string,
                   product_ids: 'Array<string> | null',
                   category_ids: 'Array<string> | null',
                   customer_ids: 'Array<string> | null'

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :promotion_id do |rule|
            rule.promotion&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          attribute :label do |rule|
            rule.respond_to?(:human_name) ? rule.human_name : rule.class.to_s.demodulize
          end

          # Association IDs for rules that wire products/taxons/users through
          # join tables. Returned as prefixed IDs to match the rest of the
          # API; null on rules that don't have the association. The matching
          # `products`/`categories`/`customers` collections below embed the
          # full records via their admin serializers so the SPA can render
          # names + extra info without an extra round-trip.
          attribute :product_ids do |rule|
            rule.products.map(&:prefixed_id) if rule.respond_to?(:products)
          end

          attribute :category_ids do |rule|
            rule.taxons.map(&:prefixed_id) if rule.respond_to?(:taxons)
          end

          attribute :customer_ids do |rule|
            rule.users.map(&:prefixed_id) if rule.respond_to?(:users)
          end

          # Embed the related records so promotion-row summaries can render
          # names + extra info without a separate fetch. Rules that don't
          # carry a given collection (e.g. an ItemTotal rule has no
          # products) skip via `if:` and the key is omitted from the
          # payload.
          many :products,
               resource: Spree.api.admin_product_serializer,
               if: proc { |rule| rule.respond_to?(:products) }

          many :taxons,
               key: :categories,
               resource: Spree.api.admin_category_serializer,
               if: proc { |rule| rule.respond_to?(:taxons) }

          many :users,
               key: :customers,
               resource: Spree.api.admin_customer_serializer,
               if: proc { |rule| rule.respond_to?(:users) }

          many :customer_groups,
               resource: Spree.api.admin_customer_group_serializer,
               if: proc { |rule| rule.respond_to?(:customer_groups) }

          many :countries,
               resource: Spree.api.admin_country_serializer,
               if: proc { |rule| rule.respond_to?(:countries) }
        end
      end
    end
  end
end
