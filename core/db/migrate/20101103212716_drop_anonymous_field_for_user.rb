class DropAnonymousFieldForUser < ActiveRecord::Migration
  def up
    unless defined?(User)
      remove_column :users, :anonymous
    end
  end

  def down
    add_column :users, :anonymous, :boolean
  end
end
