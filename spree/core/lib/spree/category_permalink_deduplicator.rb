# frozen_string_literal: true

module Spree
  # Resolves duplicate category permalinks within a store.
  #
  # Before 6.0 a permalink only had to be unique within its taxonomy, so one store
  # could legitimately hold two "catalog" roots under different taxonomies. In 6.0
  # the permalink is the category's full path and is unique per store, so those
  # rows have to be separated before the unique index can exist.
  #
  # Runs on raw SQL rather than through Spree::Category: it is called from a
  # migration, where the model's callbacks, validations and default scopes may not
  # match the schema on disk.
  class CategoryPermalinkDeduplicator
    # Two fixed variants rather than one interpolated query: spree_taxonomies is
    # gone in 6.1, and a constant is verifiably free of interpolated input.
    DUPLICATE_GROUPS_WITH_TAXONOMY_SQL = <<~SQL.freeze
      SELECT COALESCE(c.store_id, t.store_id) AS sid, c.permalink
      FROM spree_categories c
      LEFT JOIN spree_taxonomies t ON t.id = c.taxonomy_id
      WHERE c.permalink IS NOT NULL AND COALESCE(c.store_id, t.store_id) IS NOT NULL
      GROUP BY COALESCE(c.store_id, t.store_id), c.permalink
      HAVING COUNT(*) > 1
    SQL

    DUPLICATE_GROUPS_SQL = <<~SQL.freeze
      SELECT c.store_id AS sid, c.permalink
      FROM spree_categories c
      WHERE c.permalink IS NOT NULL AND c.store_id IS NOT NULL
      GROUP BY c.store_id, c.permalink
      HAVING COUNT(*) > 1
    SQL

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
    def initialize(connection = ActiveRecord::Base.connection)
      @connection = connection
    end

    # Rewrites every duplicate permalink, keeping the lowest-id row in each group
    # and re-prefixing each rewritten row's descendants so subtree paths stay
    # consistent with their parents.
    #
    # @return [Integer] number of categories whose permalink changed
    def call
      return 0 unless table_exists?

      renamed = 0

      duplicate_groups.each do |store_id, permalink|
        ids = ids_for(store_id, permalink)
        # The first row keeps the permalink; the rest have to move.
        ids.drop(1).each do |id|
          candidate = unique_permalink(permalink, id, store_id)
          rewrite(id, candidate)
          renamed += 1
        end
      end

      renamed
    end

    private

    attr_reader :connection

    def table_exists?
      connection.table_exists?('spree_categories')
    end

    # Binds values as parameters rather than interpolating them, so no user- or
    # data-derived string is ever spliced into SQL text.
    def sanitize(sql, *binds)
      ActiveRecord::Base.sanitize_sql_array([sql, *binds])
    end

    # Groups by the store a category belongs to *or is about to*: rows still
    # awaiting the upgrade backfill have a NULL store_id but resolve one through
    # their taxonomy, and they collide the moment that backfill assigns it. Both
    # cases have to be resolved before the unique index sees them.
    #
    # @return [Array<Array(Integer, String)>] (store_id, permalink) pairs appearing more than once
    def duplicate_groups
      connection.select_rows(taxonomies_table? ? DUPLICATE_GROUPS_WITH_TAXONOMY_SQL : DUPLICATE_GROUPS_SQL)
    end

    def ids_for(store_id, permalink)
      connection.select_values(sanitize(<<~SQL, store_id, permalink))
        SELECT c.id FROM spree_categories c
        #{taxonomy_join}
        WHERE #{effective_store_id} = ? AND c.permalink = ?
        ORDER BY c.id
      SQL
    end

    def taxonomy_join
      return '' unless taxonomies_table?

      'LEFT JOIN spree_taxonomies t ON t.id = c.taxonomy_id'
    end

    def effective_store_id
      taxonomies_table? ? 'COALESCE(c.store_id, t.store_id)' : 'c.store_id'
    end

    def taxonomies_table?
      return @taxonomies_table unless @taxonomies_table.nil?

      @taxonomies_table = connection.table_exists?('spree_taxonomies')
    end

    # Appends the owning taxonomy's name, falling back to a numeric suffix when
    # that is absent or itself taken.
    def unique_permalink(permalink, id, store_id)
      candidate = [permalink, taxonomy_suffix(id)].compact.join('-')
      return candidate unless taken?(candidate, store_id)

      counter = 2
      counter += 1 while taken?("#{candidate}-#{counter}", store_id)
      "#{candidate}-#{counter}"
    end

    def taxonomy_suffix(id)
      return nil unless connection.table_exists?('spree_taxonomies')

      name = connection.select_value(sanitize(<<~SQL, id))
        SELECT t.name FROM spree_taxonomies t
        INNER JOIN spree_categories c ON c.taxonomy_id = t.id
        WHERE c.id = ?
      SQL

      name.presence && name.to_s.parameterize.presence
    end

    def taken?(permalink, store_id)
      connection.select_value(sanitize(<<~SQL, store_id, permalink)).to_i.positive?
        SELECT COUNT(*) FROM spree_categories c
        #{taxonomy_join}
        WHERE #{effective_store_id} = ? AND c.permalink = ?
      SQL
    end

    # Moves the row and re-prefixes its subtree, so a child of "catalog" becomes a
    # child of "catalog-shop-b" rather than keeping the old parent's path.
    def rewrite(id, candidate)
      old_permalink = permalink_for(id)
      connection.update(sanitize('UPDATE spree_categories SET permalink = ? WHERE id = ?', candidate, id))

      descendant_ids(id).each do |descendant_id|
        current = permalink_for(descendant_id)
        next if current.blank? || !current.start_with?("#{old_permalink}/")

        moved = current.sub("#{old_permalink}/", "#{candidate}/")
        connection.update(sanitize('UPDATE spree_categories SET permalink = ? WHERE id = ?', moved, descendant_id))
      end
    end

    def permalink_for(id)
      connection.select_value(sanitize('SELECT permalink FROM spree_categories WHERE id = ?', id))
    end

    # Walks the parent chain rather than using lft/rgt, which may be stale on rows
    # an installation has not rebuilt.
    def descendant_ids(id)
      collected = []
      frontier = [id]

      until frontier.empty?
        children = connection.select_values(
          sanitize('SELECT id FROM spree_categories WHERE parent_id IN (?)', frontier)
        )
        break if children.empty?

        collected.concat(children)
        frontier = children
      end

      collected
    end
  end
end
