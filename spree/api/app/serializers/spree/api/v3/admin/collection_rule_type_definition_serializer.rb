module Spree
  module Api
    module V3
      module Admin
        # A collection rule type, with what its rule builder accepts.
        class CollectionRuleTypeDefinitionSerializer < ResourceTypeDefinitionSerializer
          typelize match_policies: [:string, multi: true, comment: 'The `match_policy` values a rule of this type accepts'],
                   value_required: [:boolean, comment: 'A rule of this type needs a `value`'],
                   uses_currency: [:boolean, comment: "Evaluated in a `currency`, the store's default when the rule names none"]

          attributes :match_policies, :value_required, :uses_currency
        end
      end
    end
  end
end
