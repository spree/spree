class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :user_defaults do |t|
      t.string :username, :password
      t.timestamps
    end
    create_table :user_no_defaults do |t|
      t.string :username, :password
      t.timestamps
    end
    create_table :user_mixeds do |t|
      t.string :username, :password
      t.timestamps
    end    
  end

  def self.down
    drop_table :user_defaults
    drop_table :user_no_defaults
    drop_table :user_mixeds
  end
end
