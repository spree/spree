class AddPhoneToSpreeUsers < ActiveRecord::Migration[6.1]
  def change
    add_column Spree.user_class.table_name, :phone, :string, if_not_exists: true
  end
end
