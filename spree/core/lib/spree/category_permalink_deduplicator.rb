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

    def quote(value)
      connection.quote(value)
    end

    # Groups by the store a category belongs to *or is about to*: rows still
    # awaiting the upgrade backfill have a NULL store_id but resolve one through
    # their taxonomy, and they collide the moment that backfill assigns it. Both
    # cases have to be resolved before the unique index sees them.
    #
    # @return [Array<Array(Integer, String)>] (store_id, permalink) pairs appearing more than once
    def duplicate_groups
      connection.select_rows(<<~SQL)
        SELECT #{effective_store_id} AS sid, c.permalink
        FROM spree_categories c
        #{taxonomy_join}
        WHERE c.permalink IS NOT NULL AND #{effective_store_id} IS NOT NULL
        GROUP BY #{effective_store_id}, c.permalink
        HAVING COUNT(*) > 1
      SQL
    end

    def ids_for(store_id, permalink)
      connection.select_values(<<~SQL)
        SELECT c.id FROM spree_categories c
        #{taxonomy_join}
        WHERE #{effective_store_id} = #{quote(store_id)} AND c.permalink = #{quote(permalink)}
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

      name = connection.select_value(<<~SQL)
        SELECT t.name FROM spree_taxonomies t
        INNER JOIN spree_categories c ON c.taxonomy_id = t.id
        WHERE c.id = #{quote(id)}
      SQL

      name.presence && name.to_s.parameterize.presence
    end

    def taken?(permalink, store_id)
      connection.select_value(<<~SQL).to_i.positive?
        SELECT COUNT(*) FROM spree_categories c
        #{taxonomy_join}
        WHERE #{effective_store_id} = #{quote(store_id)} AND c.permalink = #{quote(permalink)}
      SQL
    end

    # Moves the row and re-prefixes its subtree, so a child of "catalog" becomes a
    # child of "catalog-shop-b" rather than keeping the old parent's path.
    def rewrite(id, candidate)
      old_permalink = connection.select_value("SELECT permalink FROM spree_categories WHERE id = #{quote(id)}")
      connection.update("UPDATE spree_categories SET permalink = #{quote(candidate)} WHERE id = #{quote(id)}")

      descendant_ids(id).each do |descendant_id|
        current = connection.select_value("SELECT permalink FROM spree_categories WHERE id = #{quote(descendant_id)}")
        next if current.blank? || !current.start_with?("#{old_permalink}/")

        moved = current.sub("#{old_permalink}/", "#{candidate}/")
        connection.update("UPDATE spree_categories SET permalink = #{quote(moved)} WHERE id = #{quote(descendant_id)}")
      end
    end

    # Walks the parent chain rather than using lft/rgt, which may be stale on rows
    # an installation has not rebuilt.
    def descendant_ids(id)
      collected = []
      frontier = [id]

      until frontier.empty?
        children = connection.select_values(
          "SELECT id FROM spree_categories WHERE parent_id IN (#{frontier.map { |i| quote(i) }.join(',')})"
        )
        break if children.empty?

        collected.concat(children)
        frontier = children
      end

      collected
    end
  end
end
