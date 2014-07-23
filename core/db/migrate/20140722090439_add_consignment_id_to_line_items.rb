class AddConsignmentIdToLineItems < ActiveRecord::Migration
  def change
    change_table :spree_line_items do |t|
      t.integer :consignment_id
    end
  end
end
