class DropAnonymousFieldForUser < ActiveRecord::Migration
  def up
    remove_column :users, :anonymous
  end

  def down
    add_column :users, :anonymous, :boolean
  end
end
