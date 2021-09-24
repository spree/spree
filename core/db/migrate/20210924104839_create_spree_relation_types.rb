class CreateSpreeRelationTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_relation_types do |t|
      t.string :name
      t.text :description
      t.string :applies_to
      t.timestamps
    end
  end
end
