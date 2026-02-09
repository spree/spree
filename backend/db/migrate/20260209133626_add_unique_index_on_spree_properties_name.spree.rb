# This migration comes from spree (originally 20250730154601)
class AddUniqueIndexOnSpreePropertiesName < ActiveRecord::Migration[7.2]
  def change
    # we don't need to run this migration in multi-tenant mode as it's already handled there
    return if defined?(SpreeMultiTenant)

    # Rename duplicated properties
    duplicates = Spree::Property.select(:name).group(:name).having('COUNT(*) > 1').reorder('').pluck(:name)

    duplicates.each do |duplicate_name|
      properties = Spree::Property.where(name: duplicate_name)

      properties.each_with_index do |property, index|
        next if index == 0 # Keep the first one unchanged

        new_name = "#{duplicate_name}_#{index}"
        property.update_columns(name: new_name, updated_at: Time.current)
      end
    end

    # Add indexes
    remove_index :spree_properties, :name, if_exists: true
    add_index :spree_properties, :name, unique: true, if_not_exists: true
  end
end
