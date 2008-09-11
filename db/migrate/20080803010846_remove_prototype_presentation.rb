class RemovePrototypePresentation < ActiveRecord::Migration
  def self.up
    change_table :prototypes do |t|
      t.remove :presentation
    end    
  end

  def self.down
    change_table :prototypes do |t|
      t.string :presentation
    end    
  end
end
