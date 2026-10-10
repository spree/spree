module Spree
  module Emails
    # What an email shows for a whole purchase — who to greet, the items and
    # the summary rows — for both an order and a multi-seller purchase. The
    # `spree/shared/purchase_totals` partial reads these names from either.
    module PurchaseSummaryAttributes
      extend ActiveSupport::Concern

      included do
        typelize customer_name: :string, total_minus_store_credits: :string, display_total_minus_store_credits: :string

        attribute :customer_name do |purchase|
          purchase.name.presence || I18n.t('spree.customer')
        end

        attribute :total_minus_store_credits do |purchase|
          Spree::Money::Rounding.format(purchase.total_minus_store_credits, purchase.currency)
        end

        attribute :display_total_minus_store_credits do |purchase|
          purchase.display_total_minus_store_credits.to_s
        end

        many :line_items, key: :items, resource: Spree::Emails::LineItemSerializer
        one :billing_address, resource: Spree::Emails::AddressSerializer
        one :shipping_address, resource: Spree::Emails::AddressSerializer

        many :promotion_discounts,
             source: proc { Spree::Emails::AmountLine.group(discounts.promotion, currency: currency) },
             resource: Spree::Emails::AmountLineSerializer

        many :manual_discounts,
             source: proc { Spree::Emails::AmountLine.group(discounts.manual, currency: currency) },
             resource: Spree::Emails::AmountLineSerializer

        # A multi-seller checkout apportions an order-level fee into one row
        # per child, all under one label; summed back, it is the one charge the
        # customer saw.
        many :fee_lines,
             source: proc { Spree::Emails::AmountLine.group(fees, currency: currency) },
             resource: Spree::Emails::AmountLineSerializer
      end
    end
  end
end
