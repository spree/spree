module Spree
  module Api
    module V3
      module Seller
        # This seller's position in one currency (Spree::SellerBalance).
        #
        # A computed value rather than a record, so it carries no id.
        class BalanceSerializer < V3::BaseSerializer
          typelize currency: :string,
                   earned: :string, display_earned: :string,
                   paid: :string, display_paid: :string,
                   balance: :string, display_balance: :string,
                   pending: :string, display_pending: :string

          _attributes.delete(:id)

          attributes :currency

          %i[earned paid balance pending].each do |figure|
            attribute(figure) { |balance| balance.public_send(figure).to_s }
            attribute(:"display_#{figure}") { |balance| balance.public_send(:"display_#{figure}").to_s }
          end
        end
      end
    end
  end
end
