module Spree
  module Api
    module V3
      module Admin
        # A rule deciding when a price list applies, as price lists and catalogs write it.
        class PriceListRuleRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PriceListRuleParams'

          id :id, nullable: true, description: 'Present for existing rules. Omit to create a new one.'
          string :type, required: true, example: 'volume_rule',
                        description: 'Wire shorthand for the rule kind, from the price rule types endpoint.'
          object :preferences, description: "The rule kind's settings, keyed by preference name."
        end
      end
    end
  end
end
