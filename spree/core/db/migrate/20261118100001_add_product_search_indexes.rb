class AddProductSearchIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  TABLES = %i[spree_products spree_product_translations].freeze

  def up
    return unless Spree.postgres?

    TABLES.each do |table|
      name = "index_#{table}_on_search_vector_english"
      # An interrupted concurrent build leaves an invalid index behind.
      remove_index table, name: name, algorithm: :concurrently if indexes(table).any? { |index| index.name == name && !index.valid? }
      add_index table, vector(table), using: :gin, name: name, algorithm: :concurrently, if_not_exists: true
    end
  end

  def down
    return unless Spree.postgres?

    TABLES.each do |table|
      remove_index table, name: "index_#{table}_on_search_vector_english", algorithm: :concurrently, if_exists: true
    end
  end

  private

  # The expression Spree::SearchProvider::Postgres matches against.
  def vector(table)
    "(setweight(to_tsvector('english', coalesce(#{table}.name, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{table}.description, '')), 'B'))"
  end
end
