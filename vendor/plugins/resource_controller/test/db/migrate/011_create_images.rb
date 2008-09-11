class CreateImages < ActiveRecord::Migration
  def self.up
    create_table :images, :force => true do |t|
      t.references :user      
      t.timestamps
    end
  end

  def self.down
    drop_table :images
  end
end
