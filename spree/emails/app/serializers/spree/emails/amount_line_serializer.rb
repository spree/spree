module Spree
  module Emails
    class AmountLineSerializer
      include Alba::Resource

      attributes :label

      attribute :amount do |line|
        Spree::Money::Rounding.format(line.amount, line.currency)
      end
    end
  end
end
