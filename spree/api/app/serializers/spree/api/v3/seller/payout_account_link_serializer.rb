module Spree
  module Api
    module V3
      module Seller
        # Where a seller sets up their payout account with the payout
        # provider. Minted per request, so no id.
        class PayoutAccountLinkSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize url: [:string, nullable: true, comment: 'Null when the provider hosts no page to set the account up on']

          attributes :url
        end
      end
    end
  end
end
