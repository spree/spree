module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CollectionRule (and its STI subclasses) for the
        # admin collection editor's `rules` association. Admin-only — automatic
        # collection rules are never exposed by the Store API. `type` is the STI
        # class name (e.g. "Spree::CollectionRules::Tag").
        class CollectionRuleSerializer < BaseSerializer
          typelize type: :string, value: [:string, nullable: true], match_policy: :string

          attributes :type, :value, :match_policy
        end
      end
    end
  end
end
