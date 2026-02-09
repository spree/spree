# This migration comes from spree (originally 20250730102644)
class AddMissingUniqueIndexesToSpreeOptionTypesAndValues < ActiveRecord::Migration[7.2]
  def change
    # we don't need to run this migration in multi-tenant mode as it's already handled there
    return if defined?(SpreeMultiTenant)

    # Rename duplicated option types
    duplicates = Spree::OptionType.select(:name).group(:name).having('COUNT(*) > 1').reorder('').pluck(:name)

    duplicates.each do |duplicate_name|
      option_types = Spree::OptionType.where(name: duplicate_name)

      option_types.each_with_index do |option_type, index|
        next if index == 0 # Keep the first one unchanged

        new_name = "#{duplicate_name}_#{index}"
        option_type.update_columns(name: new_name, updated_at: Time.current)
      end
    end

    # Handle duplicates in spree_option_values
    duplicates = Spree::OptionValue.select(:option_type_id, :name).group(:option_type_id, :name).having('COUNT(*) > 1').reorder('')

    duplicates.each do |dup|
      option_values = Spree::OptionValue.where(option_type_id: dup.option_type_id, name: dup.name)

      option_values.each_with_index do |option_value, index|
        next if index == 0 # Keep the first one unchanged

        new_name = "#{option_value.name}_#{index}"
        option_value.update_columns(name: new_name, updated_at: Time.current)
      end
    end

    # Add indexes
    remove_index :spree_option_types, :name, if_exists: true
    add_index :spree_option_types, :name, unique: true, if_not_exists: true

    add_index :spree_option_values, %i[option_type_id name], unique: true, if_not_exists: true
  end
end
