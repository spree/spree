class DropExtensionMeta < ActiveRecord::Migration
  def self.up
    drop_table :extension_meta
  end

  def self.down
    create_table :extension_meta, :force => true do |t|
      t.string :name
      t.integer :schema_version, :default => 0
      t.boolean :enabled, :default => true
    end    
  end
end
