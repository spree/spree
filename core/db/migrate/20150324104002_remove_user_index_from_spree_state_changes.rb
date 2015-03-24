class RemoveUserIndexFromSpreeStateChanges < ActiveRecord::Migration
  def up
    if index_exists? :spree_state_changes, :user_id
      remove_index :spree_state_changes, :user_id
    end

  end

  def down
    unless index_exists? :spree_state_changes, :user_id
      add_index :spree_state_changes, :user_id
    end
  end
end
