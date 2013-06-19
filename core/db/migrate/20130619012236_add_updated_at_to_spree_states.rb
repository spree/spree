class AddUpdatedAtToSpreeStates < ActiveRecord::Migration
  def up
    add_column :spree_states, :updated_at, :datetime
  end

  def down
    remove_column :spree_states, :updated_at
  end
end
