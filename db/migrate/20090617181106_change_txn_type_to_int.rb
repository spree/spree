class ChangeTxnTypeToInt < ActiveRecord::Migration
  def self.up
    change_column :creditcard_txns, :txn_type, :integer
  end

  def self.down
  end
end
