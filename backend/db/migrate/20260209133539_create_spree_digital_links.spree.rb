# This migration comes from spree (originally 20210929091444)
class CreateSpreeDigitalLinks < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_digital_links, if_not_exists: true do |t|
      t.belongs_to :digital
      t.belongs_to :line_item
      t.string :secret
      t.integer :access_counter

      t.timestamps
    end
    add_index :spree_digital_links, :secret, unique: true unless index_exists?(:spree_digital_links, :secret)
  end
end
