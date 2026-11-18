module Spree
  module Emails
    # One returned line as it was credited. A customer who bought three and
    # sent one must see one, so the quantity and amount are this return's share
    # of what they paid, rather than the whole line's catalog total.
    class ReturnedItemSerializer < Spree::Emails::BaseSerializer
      include Typelizer::DSL
      include Spree::Emails::PurchasedItemAttributes

      typelize id: :string, name: :string, quantity: :number, sku: [:string, nullable: true],
               options_text: [:string, nullable: true], price: :string, amount: :string,
               url: [:string, nullable: true], image_url: [:string, nullable: true]

      attribute :id do |item|
        item.line_item.prefixed_id
      end

      attribute :name do |item|
        item.line_item.name
      end

      attribute :quantity, &:credited_quantity

      attribute :sku do |item|
        item.line_item.sku
      end

      attribute :options_text do |item|
        item.line_item.options_text
      end

      attribute :price do |item|
        Spree::Money::Rounding.format(
          item.credited_worth / item.credited_quantity,
          item.currency,
          unit_price: true
        )
      end

      attribute :amount do |item|
        Spree::Money::Rounding.format(item.credited_worth, item.currency)
      end
    end
  end
end
