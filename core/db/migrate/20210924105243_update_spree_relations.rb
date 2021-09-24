class UpdateSpreeRelations < ActiveRecord::Migration[5.2]
  def up
    Spree::Relation.where(relatable_type: 'Product').update_all(relatable_type: 'Spree::Product')
    Spree::Relation.where(related_to_type: 'Product').update_all(related_to_type: 'Spree::Product')
  end

  def down
    Spree::Relation.where(relatable_type: 'Spree::Product').update_all(relatable_type: 'Product')
    Spree::Relation.where(related_to_type: 'Spree::Product').update_all(related_to_type: 'Product')
  end
end
