class CreateSpreeRelations < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_relations, force: true do |t|
      t.decimal :discount_amount, precision: 8, scale: 2, default: 0.0
      t.integer :position
      t.references :relation_type
      t.references :relatable, polymorphic: true
      t.references :related_to, polymorphic: true
      t.timestamps
    end
  end
end
