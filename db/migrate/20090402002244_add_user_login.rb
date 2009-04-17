class AddUserLogin < ActiveRecord::Migration
  def self.up   
    change_table :users do |t|
      t.string :login, :unique => true
    end

    User.reset_column_information

    execute "UPDATE users SET login = email"
  end

  def self.down                       
    change_table :users do |t|
      t.remove :login
    end
  end
end
