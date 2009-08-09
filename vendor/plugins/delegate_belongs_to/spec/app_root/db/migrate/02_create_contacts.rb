class CreateContacts < ActiveRecord::Migration
  def self.up
    create_table :contacts do |t|
      t.string :firstname, :lastname
      t.integer :parent_id, :lft
    end
  end
  
  def self.down
    drop_table :contacts
  end
end