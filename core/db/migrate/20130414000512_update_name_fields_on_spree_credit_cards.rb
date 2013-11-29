class UpdateNameFieldsOnSpreeCreditCards < ActiveRecord::Migration
  def up
    if ActiveRecord::Base.connection.adapter_name.downcase.include? "mysql"
      execute "UPDATE spree_credit_cards SET name = CONCAT(first_name, ' ', last_name)"
    else
      execute "UPDATE spree_credit_cards SET name = first_name || ' ' || last_name"
    end
  end

  def down
    execute "UPDATE spree_credit_cards SET name = NULL"
  end
end
