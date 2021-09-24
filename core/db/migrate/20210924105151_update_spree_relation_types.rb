class UpdateSpreeRelationTypes < ActiveRecord::Migration[6.0]
  def up
    Spree::RelationType.where(applies_to: 'Product').update_all(applies_to: 'Spree::Product')
  end

  def down
    Spree::RelationType.where(applies_to: 'Spree::Product').update_all(applies_to: 'Product')
  end
end
