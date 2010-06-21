class CreditcardTxn < Transaction

  enumerable_constant :txn_type, :constants => [:authorize, :capture, :purchase, :void, :credit]
  
  def txn_type_name
    TxnType.from_value(txn_type)
  end

end