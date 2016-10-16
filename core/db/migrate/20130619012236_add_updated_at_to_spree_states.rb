class AddUpdatedAtToSpreeStates < ActiveRecord::Migration[4.2]
  def up
    add_column :spree_states, :updated_at, :datetime
  end

  def down
    remove_column :spree_states, :updated_at
  end
end
