class RenameCreditTypes < ActiveRecord::Migration
  def change
    default_type = Spree::StoreCreditType.where(name: 'Promotional').first
    default_type.update_column(:name, 'Expiring')
    Spree::StoreCreditType.create(name: 'Non-expiring', priority: 2)
  end
end
