class AddDefaultCountryKindToSpreeZones < ActiveRecord::Migration[5.2]
  def change
    change_column_default(:spree_zones, :kind, :state)
  end
end
