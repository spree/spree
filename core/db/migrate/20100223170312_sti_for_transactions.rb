class StiForTransactions < ActiveRecord::Migration
  def up
    rename_table  :creditcard_txns, :transactions
    add_column    :transactions, :type, :string
    remove_column :transactions, :creditcard_id

    execute "UPDATE transactions SET type = 'CreditcardTxn'"
  end

  def down
    rename_table  :transactions, :creditcard_txns
    remove_column :transactions, :type
    add_column    :transactions, :creditcard_id, :integer
  end
end
