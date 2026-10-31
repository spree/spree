class DeleteOrphanedSpreeOptionValueVariants < ActiveRecord::Migration[8.1]
  # Replacing a variant's option_value_variants used to nullify the old join rows instead of
  # deleting them. Rows with no variant belong to nothing and block new variants from reusing
  # their option values through the uniqueness validation scoped to a NULL variant_id.
  def up
    execute 'DELETE FROM spree_option_value_variants WHERE variant_id IS NULL'
  end

  def down; end
end
