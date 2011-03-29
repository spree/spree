class CreatePromotionActions < ActiveRecord::Migration
  def self.up
    create_table :promotion_actions do |t|
      t.integer :activator_id
      t.integer :position
      t.string :type
    end
  end

  def self.down
    drop_table :promotion_actions
  end
end
