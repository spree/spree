class AddNicknameToAddress < ActiveRecord::Migration
  def self.up
    add_column :addresses, :nickname, :string
  end

  def self.down
    remove_column :addresses, :nickname
  end
end
