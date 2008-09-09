class AddStateNameToAddress < ActiveRecord::Migration
  def self.up
    add_column :addresses, :state_name, :string
  end

  def self.down
    remove_column :addresses, :state_name
  end
end
