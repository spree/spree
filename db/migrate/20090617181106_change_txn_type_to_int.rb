class ChangeTxnTypeToInt < ActiveRecord::Migration
  def self.up
    if (ActiveRecord::Migration.connection.adapter_name == "PostgreSQL") && (postgresql_version > 80000)
      
      execute('
        ALTER TABLE "creditcard_txns" 
          ALTER COLUMN "txn_type" 
          TYPE integer 
          USING to_number(creditcard_txns.txn_type,\'S9999999\')
      ')
    else
      change_column :creditcard_txns, :txn_type, :integer
    end
  end

  def self.down
  end
end
