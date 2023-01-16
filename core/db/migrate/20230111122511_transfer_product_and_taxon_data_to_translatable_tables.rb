class TransferProductAndTaxonDataToTranslatableTables < ActiveRecord::Migration[6.1]
  DEFAULT_LOCALE = 'en'
  PRODUCTS_TABLE = 'spree_products'
  PRODUCT_TRANSLATIONS_TABLE = 'spree_product_translations'
  TAXONS_TABLE = 'spree_taxons'
  TAXON_TRANSLATIONS_TABLE = 'spree_taxon_translations'

  def up
    # Only transfer data if translation tables are being newly created / no translations exist
    # Otherwise, assume translation data is already in place from spree_globalize

    # Products
    if not Spree::Product::Translation.exists?
      ActiveRecord::Base.connection.execute("
      INSERT INTO #{PRODUCT_TRANSLATIONS_TABLE} (name, description, locale, spree_product_id, created_at, updated_at, meta_description, meta_keywords, meta_title, slug)
      SELECT name, description, '#{DEFAULT_LOCALE}' as locale, id, created_at, updated_at, meta_description, meta_keywords, meta_title, slug FROM #{PRODUCTS_TABLE};
                                            ")
      ActiveRecord::Base.connection.execute("
      UPDATE #{PRODUCTS_TABLE}
      SET name=null, description=null, meta_description=null, meta_keywords=null, meta_title=null, slug=null;
                                            ")
    end

    # Taxons
    if not Spree::Taxon::Translation.exists?
      ActiveRecord::Base.connection.execute("
      INSERT INTO #{TAXON_TRANSLATIONS_TABLE} (name, description, meta_title, meta_description, meta_keywords, permalink, locale, spree_taxon_id, created_at, updated_at)
      SELECT name, description, meta_title, meta_description, meta_keywords, permalink, '#{DEFAULT_LOCALE}' as locale, id, created_at, updated_at FROM #{TAXONS_TABLE};
                                            ")
      ActiveRecord::Base.connection.execute("
      UPDATE #{TAXONS_TABLE}
      SET name=null, description=null, meta_title=null, meta_description=null, meta_keywords=null, permalink=null;
                                            ")
    end
  end

  def down
    ActiveRecord::Base.connection.execute("
      UPDATE #{PRODUCTS_TABLE} as products
      SET (name,
           description,
           meta_description,
           meta_keywords,
           meta_title,
           slug) =
          (t_products.name,
           t_products.description,
           t_products.meta_description,
           t_products.meta_keywords,
           t_products.meta_title,
           t_products.slug)
      FROM #{PRODUCT_TRANSLATIONS_TABLE} AS t_products
      WHERE t_products.spree_product_id = products.id
    ")

    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE #{PRODUCT_TRANSLATIONS_TABLE}
                                          ")

    ActiveRecord::Base.connection.execute("
      UPDATE #{TAXONS_TABLE} as taxons
      SET (name,
           description,
           meta_title,
           meta_description,
           meta_keywords,
           permalink) =
          (t_taxons.name,
           t_taxons.description,
           t_taxons.meta_title,
           t_taxons.meta_description,
           t_taxons.meta_keywords,
           t_taxons.permalink)
      FROM #{TAXON_TRANSLATIONS_TABLE} AS t_taxons
      WHERE t_taxons.spree_taxon_id = taxons.id
    ")

    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE #{TAXON_TRANSLATIONS_TABLE}
                                          ")
  end
end
