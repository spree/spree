class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :accounts
  end
end
