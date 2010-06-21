Factory.define :payment do |f|
  f.amount 45.75
  f.payment_method { Gateway.current }
  f.source { Factory.build(:creditcard) }
  f.payable { Factory(:checkout) }

  # limit the payment amount to order's remaining balance, to avoid over-pay exceptions
  f.after_create do |pmt| 
    if pmt.payable && pmt.payable.respond_to?(:order) && o = pmt.payable.order
      pmt.update_attribute(:amount, [pmt.amount, o.outstanding_balance].min) 
    end
  end
end

Factory.define :creditcard_txn do |f|
  f.association :payment
  f.amount 45.75
  f.response_code 12345
  f.txn_type CreditcardTxn::TxnType::AUTHORIZE

  # match the payment amount to the payment's value
  f.after_create do |txn| 
    # txn.update_attribute(:amount, [txn.amount, txn.payment.payment].min)
    txn.update_attribute(:amount, txn.payment.amount)
  end
end
