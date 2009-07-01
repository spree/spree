class CreateCredits < ActiveRecord::Migration
  def self.up
    create_table :credits do |t|
      t.references :order
      t.decimal :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string :description
      t.integer :position
      t.references :creditable, :polymorphic => true
      t.timestamps
    end    
    change_table :orders do |t|
      t.decimal :credit_total, :precision => 8, :scale => 2, :default => 0.0, :null => false      
    end
  end

  def self.down
    drop_table :credits
    change_table :orders do |t|
      t.remove :credit_total      
    end
  end
end
