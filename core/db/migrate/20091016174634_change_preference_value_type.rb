class ChangePreferenceValueType < ActiveRecord::Migration
  def self.up
    remove_index :preferences, :name => 'index_preferences_on_owner_and_attribute_and_preference'
    change_column :preferences, :value, :text
  end

  def self.down
    change_column :preferences, :value, :string
  end
end
