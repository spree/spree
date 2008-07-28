class RenameTxnTable < ActiveRecord::Migration
  def self.up
    rename_table :txns, :credit_card_txns
  end

  def self.down
    rename_table :credit_card_txns, :txns
  end
end
