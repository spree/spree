class CreateExtensionMeta < ActiveRecord::Migration
  def self.up
    create_table 'extension_meta', :force => true do |t|
      t.string :name
      t.integer :schema_version, :default => 0
      t.boolean :enabled, :default => true
    end
  end

  def self.down
    drop_table 'extension_meta'
  end
end