class ChangeStatesRequiredForCountries < ActiveRecord::Migration
  def up
    change_column_default :spree_countries, :states_required, false
  end

  def down
    change_column_default :spree_countries, :states_required, true
  end
end
