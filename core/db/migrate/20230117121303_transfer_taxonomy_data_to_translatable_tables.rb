class TransferTaxonomyDataToTranslatableTables < ActiveRecord::Migration[6.1]
  TRANSLATION_MIGRATION = Spree::TranslationMigrations.new(Spree::Taxonomy, 'en')

  def up
    TRANSLATION_MIGRATION.transfer_translation_data
  end

  def down
    TRANSLATION_MIGRATION.revert_translation_data_transfer
  end
end
