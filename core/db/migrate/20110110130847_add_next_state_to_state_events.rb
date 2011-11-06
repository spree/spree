class AddNextStateToStateEvents < ActiveRecord::Migration
  def change
    add_column :state_events, :next_state, :string
  end
end
