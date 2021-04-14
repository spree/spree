class AddDefaultCountryKindToSpreeZones < ActiveRecord::Migration[6.0]
  def change
    change_column_default(:spree_zones, :kind, :state)
  end
end
