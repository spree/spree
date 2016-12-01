class AddReasonToSpreeStateChanges < ActiveRecord::Migration
  def change
    add_column :spree_state_changes, :reason, :text
  end
end
