class ChangeLimitForNameAndPresentationForOptionTypes < ActiveRecord::Migration
  def up
    change_column :spree_option_types, :name, :string, limit: 500
    change_column :spree_option_types, :presentation, :string, limit: 500
  end

  def down
    change_column :spree_option_types, :name, :string, limit: 100
    change_column :spree_option_types, :presentation, :string, limit: 100
  end     
end
