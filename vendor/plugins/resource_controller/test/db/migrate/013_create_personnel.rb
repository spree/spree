class CreatePersonnel < ActiveRecord::Migration
  def self.up
    create_table :personnel, :force => true do |t|
      t.timestamps
    end
  end

  def self.down
    drop_table :personnel
  end
end
