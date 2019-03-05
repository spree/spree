class AddIsoAndIso3ValidationOnPresenceAndUniqueness < ActiveRecord::Migration[5.2]
  def up
    Spree::Country.where.not(id: Spree::Country.group(:iso).select("min(id)")).destroy_all
    Spree::Country.where.not(id: Spree::Country.group(:iso3).select("min(id)")).destroy_all

    change_column_null(:spree_countries, :iso, false)
    change_column_null(:spree_countries, :iso3, false)
    add_index :spree_countries, :iso, unique: true
    add_index :spree_countries, :iso3, unique: true
  end

  def down
    change_column_null(:spree_countries, :iso, true)
    change_column_null(:spree_countries, :iso3, true)
    remove_index :spree_countries, :iso, unique: true
    remove_index :spree_countries, :iso3, unique: true
  end
end
