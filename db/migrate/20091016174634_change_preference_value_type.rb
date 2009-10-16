class ChangePreferenceValueType < ActiveRecord::Migration
  def self.up
		change_column :preferences, :value, :text
  end

  def self.down
		change_column :preferences, :value, :string
  end
end
