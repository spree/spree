module Spree
  module Emails
    class AmountLineSerializer
      include Alba::Resource

      attributes :label

      attribute :display_amount do |line|
        line.display_amount.to_s
      end

      attribute :amount do |line|
        Spree::Money::Rounding.format(line.amount, line.currency)
      end
    end
  end
end
