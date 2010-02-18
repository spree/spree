Factory.define :payment do |f|
  f.amount 45.75
  f.payment_method { Gateway.current }
  f.source { Factory.build(:creditcard) }
  f.payable { Factory(:checkout) }
end

Factory.define :creditcard_txn do |f|
  f.association :payment
  f.amount 45.75
  f.response_code 12345
  f.txn_type CreditcardTxn::TxnType::AUTHORIZE
end