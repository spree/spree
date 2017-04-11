class AddIndexesForPropertyPrototype < ActiveRecord::Migration[5.0]
  def change
    duplicates = Spree::PropertyPrototype.group(:prototype_id, :property_id).having('sum(1) > 1').size

    duplicates.each do |f|
      prototype_id, property_id = f.first
      count = f.last - 1 # we want to leave one record
      prototypes = Spree::PropertyPrototype.where(prototype_id: prototype_id, property_id: property_id).last(count)
      prototypes.map(&:destroy)
    end

    if index_exists? :spree_property_prototypes, [:prototype_id, :property_id]
      remove_index :spree_property_prototypes, [:prototype_id, :property_id]
      add_index :spree_property_prototypes, [:prototype_id, :property_id], unique: true, name: 'index_property_prototypes_on_prototype_id_and_property_id'
    end

    add_index :spree_property_prototypes, :prototype_id
    add_index :spree_property_prototypes, :property_id
  end
end
