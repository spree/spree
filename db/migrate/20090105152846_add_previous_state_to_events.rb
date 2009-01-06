class AddPreviousStateToEvents < ActiveRecord::Migration
  def self.up
    change_table :state_events do |t|
      t.string :previous_state
    end
  end

  def self.down
    change_table :state_events do |t|
      t.remove :previous_state
    end
  end
end
