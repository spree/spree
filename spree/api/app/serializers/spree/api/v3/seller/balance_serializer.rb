module Spree
  module Api
    module V3
      module Seller
        # This seller's position in one currency (Spree::SellerBalance).
        #
        # A computed value rather than a record, so it carries no id.
        class BalanceSerializer < V3::BaseSerializer
          typelize currency: :string,
                   settlement_currency: :string,
                   converted: :boolean,
                   earned: :string,
                   payable: :string,
                   paid: :string,
                   balance: :string,
                   pending: :string

          _attributes.delete(:id)

          # Two sides when the account settles in another currency: what the
          # sales were worth, and what the account received once the provider
          # converted. Never added together.
          attributes :currency, :settlement_currency

          attribute(:converted) { |balance| balance.converted? }

          # Earnings are in the currency the sales were priced in; what the
          # account holds is in the one it settles in.
          %i[earned pending].each do |figure|
            attribute(figure) { |balance| Spree::Money::Rounding.format(balance.public_send(figure), balance.currency) }
          end

          %i[payable paid balance].each do |figure|
            attribute(figure) { |balance| Spree::Money::Rounding.format(balance.public_send(figure), balance.settlement_currency) }
          end
        end
      end
    end
  end
end
