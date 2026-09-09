module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CollectionRule (and its STI subclasses) for the
        # admin collection editor's `rules` association. Admin-only — automatic
        # collection rules are never exposed by the Store API. `type` is the STI
        # class name (e.g. "Spree::CollectionRules::Tag").
        class CollectionRuleSerializer < BaseSerializer
          typelize type: [:string, comment: 'Rule class name. Built-in: Spree::CollectionRules::Tag, Spree::CollectionRules::AvailableOn, Spree::CollectionRules::Sale. Extensions may register more.'], value: [:string, nullable: true], match_policy: [:string, enum: Spree::CollectionRule::MATCH_POLICIES]

          attributes :type, :value, :match_policy
        end
      end
    end
  end
end
