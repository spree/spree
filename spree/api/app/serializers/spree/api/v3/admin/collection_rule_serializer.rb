module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CollectionRule (and its STI subclasses) for the
        # admin collection editor's `rules` association. Admin-only — automatic
        # collection rules are never exposed by the Store API. `type` is the
        # wire shorthand (e.g. "tag"), matching every other typed-rule
        # serializer and what the writer accepts.
        class CollectionRuleSerializer < BaseSerializer
          typelize type: [:string, comment: 'Rule type. Built-in: tag, available_on, sale, category, product_type, price, in_stock, ' \
                                            'title, seller, custom_field. Extensions may register more.'],
                   value: [:string, nullable: true, comment: 'A prefixed id for rule types that name a record.'],
                   match_policy: [:string, enum: Spree::CollectionRule::MATCH_POLICIES, enum_type_name: 'CollectionRuleMatchPolicy'],
                   currency: [:string, nullable: true],
                   preferences: 'Record<string, unknown>'

          attributes :match_policy, :currency

          attribute :value, &:api_value

          attribute :preferences, &:serialized_preferences

          attribute :type do |rule|
            rule.class.api_type
          end
        end
      end
    end
  end
end
