class CreateRelationTypes < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_relation_types do |t|
      t.string :name
      t.text :description
      t.string :applies_to
      t.timestamps
    end
  end
end
