class ChangeStatesRequiredForCountries < ActiveRecord::Migration[4.2]
  def up
    change_column_default :spree_countries, :states_required, false
  end

  def down
    change_column_default :spree_countries, :states_required, true
  end
end
