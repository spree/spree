class Payment < ActiveRecord::Base
  belongs_to :order
  after_update :check_payments
  after_destroy :check_payments

  validate :amount_is_valid_for_outstanding_balance_or_credit

  private
  def check_payments
    return unless order.checkout_complete && can_capture?
    #sorting by created_at.to_f to ensure millisecond percsision, plus ID - just in case
    events = order.state_events.sort_by { |e| [e.created_at.to_f, e.id] }.reverse

    if order.returnable_units.nil? && order.return_authorizations.size >0
      order.return!
    elsif %w(over_paid under_paid).include?(events.first.name)
      events.each do |event|
        if %w(shipped paid new).include?(event.previous_state)
          order.update_attribute("state", event.previous_state)

          return
        end
      end
    elsif order.payment_total >= order.total
      order.pay!
    end
  end
  
  def amount_is_valid_for_outstanding_balance_or_credit
    if amount < 0
      if amount.abs > order.outstanding_credit
        errors.add(:amount, "Is greater than the credit owed (#{order.outstanding_credit})")
      end
    else
      if amount > order.outstanding_balance
        errors.add(:amount, "Is greater than the outstanding balance (#{order.outstanding_balance})")
      end
    end    
  end
  
end