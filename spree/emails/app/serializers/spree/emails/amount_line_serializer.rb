module Spree
  module Emails
    class AmountLineSerializer
      include Alba::Resource

      attributes :label, :display_amount

      attribute :amount do |line|
        line.amount.to_s
      end
    end
  end
end
