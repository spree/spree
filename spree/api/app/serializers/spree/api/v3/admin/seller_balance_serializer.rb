module Spree
  module Api
    module V3
      module Admin
        # A seller's position in one currency (Spree::SellerBalance), for the
        # operator. A computed value rather than a record, so it carries no id.
        class SellerBalanceSerializer < V3::BaseSerializer
          typelize seller_id: :string,
                   currency: :string,
                   earned: :string, display_earned: :string,
                   paid: :string, display_paid: :string,
                   balance: :string, display_balance: :string,
                   pending: :string, display_pending: :string

          _attributes.delete(:id)

          attributes :currency

          attribute(:seller_id) { |balance| balance.seller&.prefixed_id }

          %i[earned paid balance pending].each do |figure|
            attribute(figure) { |balance| balance.public_send(figure).to_s }
            attribute(:"display_#{figure}") { |balance| balance.public_send(:"display_#{figure}").to_s }
          end
        end
      end
    end
  end
end
