class CreatePrototypes < ActiveRecord::Migration
  def self.up
    create_table :prototypes do |t|
      t.string :name, :unique => true
      t.string :presentation, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :prototypes
  end
end
