module Spree
  # What a purchase owes right now, derived on read from its terms and its
  # payments — never stored, so it cannot drift from the money it describes.
  #
  # A retail order's schedule is the whole total due now and nothing after,
  # which is what every surface showed before deposits existed.
  class PaymentSchedule
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :amount_due_now, :decimal, default: 0
    attribute :deposit_amount, :decimal
    attribute :deposit_paid, :boolean, default: false
    attribute :outstanding_balance, :decimal, default: 0
    attribute :balance_due_label, :string

    # @return [Boolean] whether anything is still owed
    def outstanding?
      outstanding_balance.to_d.positive?
    end

    def as_json(*)
      {
        'amount_due_now' => amount_due_now.to_s,
        'deposit_amount' => deposit_amount&.to_s,
        'deposit_paid' => deposit_paid,
        'outstanding_balance' => outstanding_balance.to_s,
        'balance_due_label' => balance_due_label
      }
    end
  end
end
