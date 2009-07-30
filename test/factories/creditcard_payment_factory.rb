Factory.define :creditcard_payment do |f|
  f.association :creditcard
  f.creditcard_txns { [Factory(:creditcard_txn, :txn_type => CreditcardTxn::TxnType::AUTHORIZE)] }
  f.association :order
end

Factory.define :creditcard_txn do |f|
  f.amount 45.75
  f.response_code 12345
  f.txn_type CreditcardTxn::TxnType::AUTHORIZE
end