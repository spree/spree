class MakeStateEventsPolymorphic < ActiveRecord::Migration
  def up
    rename_column :state_events, :order_id, :stateful_id
    add_column :state_events, :stateful_type, :string
    execute "UPDATE state_events SET stateful_type = 'Order'"
  end

  def down
    rename_column :state_events, :stateful_id, :order_id
    remove_column :state_events, :stateful_type
  end
end
