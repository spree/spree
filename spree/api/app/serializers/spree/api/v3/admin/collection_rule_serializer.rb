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
          typelize type: [:string, comment: 'Rule type. Built-in: tag, available_on, sale. Extensions may register more.'], value: [:string, nullable: true], match_policy: [:string, enum: Spree::CollectionRule::MATCH_POLICIES]

          attributes :value, :match_policy

          attribute :type do |rule|
            rule.class.api_type
          end
        end
      end
    end
  end
end
