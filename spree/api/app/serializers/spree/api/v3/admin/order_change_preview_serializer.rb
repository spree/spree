module Spree
  module Api
    module V3
      module Admin
        class OrderChangePreviewSerializer < V3::BaseSerializer
          _attributes.delete(:id)

          typelize currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode']

          attributes :currency

          money_attributes :item_total, :discount_total, :delivery_total, :tax_total, :included_tax_total,
                           :additional_tax_total, :fee_total, :total,
                           :previous_total, :outstanding_balance, :balance_delta,
                           descriptions: {
                             total: 'The order total after the change.',
                             previous_total: 'The order total before the change.',
                             outstanding_balance: 'What the customer would still owe after the change. Negative when they would be owed money back.',
                             balance_delta: 'How far the order total moves: positive when it goes up, negative when it goes down. ' \
                                            'Whether the customer owes money or is owed some is outstanding_balance.'
                           }
        end
      end
    end
  end
end
