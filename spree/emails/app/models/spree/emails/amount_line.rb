module Spree
  module Emails
    # One labelled amount on an email's summary: a promotion, a manual
    # discount, a delivery rate or a fee, with rows sharing a label summed.
    class AmountLine
      include ActiveModel::Model
      include ActiveModel::Attributes
      extend Spree::DisplayMoney

      attribute :label, :string
      attribute :amount, :decimal
      attribute :currency, :string

      money_methods :amount

      # Sums records sharing a label into one line each.
      #
      # @param records [Enumerable] the rows to sum
      # @param currency [String]
      # @param label [Symbol, Proc] names each row
      # @param amount [Symbol] the method giving each row's amount
      # @param keep_zero [Boolean] whether a line coming to zero is kept
      # @return [Array<Spree::Emails::AmountLine>]
      def self.group(records, currency:, label: :label, amount: :amount, keep_zero: false)
        records.to_a.group_by(&label).filter_map do |name, rows|
          sum = rows.sum { |row| row.public_send(amount).to_d }
          new(label: name, amount: sum, currency: currency) if keep_zero || !sum.zero?
        end
      end
    end
  end
end
