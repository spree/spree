class TransferStoreDataToTranslatableTables < ActiveRecord::Migration[6.1]
  TRANSLATION_MIGRATION = Spree::TranslationMigrations.new(Spree::Store, 'en')

  def up
    TRANSLATION_MIGRATION.transfer_translation_data
  end

  def down
    TRANSLATION_MIGRATION.revert_translation_data_transfer
  end
end
