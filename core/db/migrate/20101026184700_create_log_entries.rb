class CreateLogEntries < ActiveRecord::Migration
  def self.up
    create_table :log_entries do |t|
      t.integer :source_id
      t.string :source_type
      t.text :details

      t.timestamps
    end
  end

  def self.down
    drop_table :log_entries
  end
end
