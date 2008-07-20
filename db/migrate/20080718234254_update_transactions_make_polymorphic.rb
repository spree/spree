class UpdateTransactionsMakePolymorphic < ActiveRecord::Migration
  def self.up
    rename_column :txns, :credit_card_id, :transactable_id
    change_table :txns do |t|
      t.string :transactable_type
    end    
    # update any existing transactions 
    execute "UPDATE txns SET transactable_type = 'CreditCard' WHERE transactable_type IS NULL"
  end

  def self.down
    t.rename_column :txns, :transactable_id, :credit_card_id
    change_table :txns do |t|
      t.remove :transactable_type
    end    
  end
end
