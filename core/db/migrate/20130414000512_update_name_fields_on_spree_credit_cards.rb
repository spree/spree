class UpdateNameFieldsOnSpreeCreditCards < ActiveRecord::Migration
  def up
    execute "UPDATE spree_credit_cards SET name = first_name || ' ' || last_name"
  end

  def down
    execute "UPDATE spree_credit_cards SET name = NULL"
  end
end
