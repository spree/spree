# This migration comes from spree (originally 20220804073928)
class TransferDataToTranslatableTables < ActiveRecord::Migration[7.0]
  DEFAULT_LOCALE = 'en'
  PRODUCTS_TABLE = 'spree_products'
  PRODUCT_TRANSLATIONS_TABLE = 'spree_product_translations'
  TAXONS_TABLE = 'spree_taxons'
  TAXON_TRANSLATIONS_TABLE = 'spree_taxon_translations'

  def up
    # Products
    ActiveRecord::Base.connection.execute("
      INSERT INTO #{PRODUCT_TRANSLATIONS_TABLE} (name, description, locale, spree_product_id, created_at, updated_at, meta_description, meta_keywords, meta_title, slug)
      SELECT name, description, '#{DEFAULT_LOCALE}' as  locale, id, created_at, updated_at, meta_description, meta_keywords, meta_title, slug FROM #{PRODUCTS_TABLE}
                                          ")
    #Taxons
    ActiveRecord::Base.connection.execute("
      INSERT INTO #{TAXON_TRANSLATIONS_TABLE} (name, description, locale, spree_taxon_id, created_at, updated_at)
      SELECT name, description, '#{DEFAULT_LOCALE}' as  locale, id, created_at, updated_at FROM #{TAXONS_TABLE}
                                          ")
  end

  def down
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE #{PRODUCT_TRANSLATIONS_TABLE}
                                          ")
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE #{TAXON_TRANSLATIONS_TABLE}
                                          ")
  end
end
