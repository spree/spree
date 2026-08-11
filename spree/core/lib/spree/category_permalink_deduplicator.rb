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
    # Spelled out per schema rather than interpolated from #effective_store_id:
    # this query binds no values, so writing it as constants keeps it provably
    # free of interpolated input (Brakeman flags the assembled form). The queries
    # below interpolate the same fragments but bind their values via #sanitize.
    DUPLICATE_GROUPS_WITH_TAXONOMY_SQL = <<~SQL.freeze
      SELECT COALESCE(c.store_id, t.store_id) AS sid, c.permalink
      FROM spree_categories c
      LEFT JOIN spree_taxonomies t ON t.id = c.taxonomy_id
      WHERE c.permalink IS NOT NULL AND COALESCE(c.store_id, t.store_id) IS NOT NULL
      GROUP BY COALESCE(c.store_id, t.store_id), c.permalink
      HAVING COUNT(*) > 1
    SQL

    TRANSLATION_GROUPS_WITH_TAXONOMY_SQL = <<~SQL.freeze
      SELECT COALESCE(c.store_id, t.store_id) AS sid, tr.locale, tr.permalink
      FROM spree_category_translations tr
      INNER JOIN spree_categories c ON c.id = tr.spree_category_id
      LEFT JOIN spree_taxonomies t ON t.id = c.taxonomy_id
      WHERE tr.permalink IS NOT NULL AND COALESCE(c.store_id, t.store_id) IS NOT NULL
      GROUP BY COALESCE(c.store_id, t.store_id), tr.locale, tr.permalink
      HAVING COUNT(*) > 1
    SQL

    TRANSLATION_GROUPS_SQL = <<~SQL.freeze
      SELECT c.store_id AS sid, tr.locale, tr.permalink
      FROM spree_category_translations tr
      INNER JOIN spree_categories c ON c.id = tr.spree_category_id
      WHERE tr.permalink IS NOT NULL AND c.store_id IS NOT NULL
      GROUP BY c.store_id, tr.locale, tr.permalink
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
      @permalinks_by_store = {}
    end

    # Rewrites every duplicate permalink, keeping the lowest-id row in each group
    # and re-prefixing each rewritten row's descendants so subtree paths stay
    # consistent with their parents.
    #
    # @return [Integer] number of categories whose permalink changed
    def call
      return 0 unless connection.table_exists?('spree_categories')

      renamed = 0

      # Re-queried each round rather than snapshotted once: re-prefixing a
      # subtree can move a descendant onto a path some other row already holds,
      # and that collision has to be resolved too or the unique index cannot be
      # created. Each round strictly reduces the duplicates, so this terminates.
      while (groups = duplicate_groups).any?
        # A cascade rewrites descendants directly, so the cached permalink sets
        # are stale by the end of a round.
        @permalinks_by_store.clear
        moved = resolve_groups(groups)
        break if moved.zero? # defensive: never spin if a group cannot be moved

        renamed += moved
      end

      # Independent of the base pass: a store whose base permalinks are already
      # unique can still hold colliding translated ones, and the storefront
      # resolves categories through that table.
      renamed + rewrite_translations
    end

    private

    # @return [Integer] rows moved in this round
    def resolve_groups(groups)
      moved = 0

      groups.each do |store_id, permalink|
        ids = ids_for(store_id, permalink)
        # The first row keeps the permalink; the rest have to move.
        ids.drop(1).each do |id|
          candidate = unique_permalink(permalink, id, store_id)
          rewrite(id, permalink, candidate)
          permalinks_for(store_id) << candidate
          moved += 1
        end
      end

      moved
    end

    private

    attr_reader :connection

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
    # Shallowest paths first. A parent must be rewritten before its children, so
    # the subtree re-prefix in #rewrite fixes them; otherwise a child rewritten
    # first gets a suffix of its own and is then re-prefixed too, leaving paths
    # like "catalog-shop-b/kids-shop-b". SQL returns groups in no defined order.
    def duplicate_groups
      rows = connection.select_rows(taxonomies_table? ? DUPLICATE_GROUPS_WITH_TAXONOMY_SQL : DUPLICATE_GROUPS_SQL)
      rows.sort_by { |_store_id, permalink| permalink.to_s.count('/') }
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
      return nil unless taxonomies_table?

      name = connection.select_value(sanitize(<<~SQL, id))
        SELECT t.name FROM spree_taxonomies t
        INNER JOIN spree_categories c ON c.taxonomy_id = t.id
        WHERE c.id = ?
      SQL

      name.presence && name.to_s.parameterize.presence
    end

    def taken?(permalink, store_id)
      permalinks_for(store_id).include?(permalink)
    end

    # Every permalink in the store, loaded once. COALESCE on store_id defeats the
    # index, so testing candidates in memory beats a scan per candidate — and the
    # numeric-suffix loop tries several per collision.
    def permalinks_for(store_id)
      @permalinks_by_store[store_id] ||= connection.select_values(sanitize(<<~SQL, store_id)).compact.to_set
        SELECT c.permalink FROM spree_categories c
        #{taxonomy_join}
        WHERE #{effective_store_id} = ? AND c.permalink IS NOT NULL
      SQL
    end

    # Moves the row and re-prefixes its subtree, so a child of "catalog" becomes a
    # child of "catalog-shop-b" rather than keeping the old parent's path.
    def rewrite(id, old_permalink, candidate)
      connection.update(sanitize('UPDATE spree_categories SET permalink = ? WHERE id = ?', candidate, id))

      descendants(id).each do |descendant_id, current|
        next if current.blank? || !current.start_with?("#{old_permalink}/")

        moved = current.sub("#{old_permalink}/", "#{candidate}/")
        connection.update(sanitize('UPDATE spree_categories SET permalink = ? WHERE id = ?', moved, descendant_id))
      end
    end

    # The storefront resolves a category by its *translated* permalink
    # (`scope.i18n.find_by!(permalink:)`), and that table carries no uniqueness
    # constraint — so a collision there survives the base-column pass and makes
    # the lookup return whichever row it happens to reach first. Each locale is a
    # separate namespace, so each is deduplicated on its own.
    def rewrite_translations
      return 0 unless connection.table_exists?('spree_category_translations')

      renamed = 0

      while (groups = translation_duplicate_groups).any?
        moved = resolve_translation_groups(groups)
        break if moved.zero?

        renamed += moved
      end

      renamed
    end

    # @return [Integer] translation rows moved in this round
    def resolve_translation_groups(groups)
      renamed = 0

      groups.each do |store_id, locale, permalink|
        rows = translation_rows_for(store_id, locale, permalink)
        taken = translation_permalinks_for(store_id, locale)

        # The first row keeps the permalink; the rest have to move.
        rows.drop(1).each do |translation_id, category_id|
          counter = 2
          counter += 1 while taken.include?("#{permalink}-#{counter}")
          candidate = "#{permalink}-#{counter}"
          taken << candidate

          move_translation(translation_id, candidate)
          # Children's translated paths are built from the parent's, so they have
          # to follow it exactly as they do on the base column.
          reprefix_descendant_translations(category_id, locale, permalink, candidate)
          renamed += 1
        end
      end

      renamed
    end

    def move_translation(translation_id, permalink)
      connection.update(
        sanitize('UPDATE spree_category_translations SET permalink = ? WHERE id = ?', permalink, translation_id)
      )
    end

    def reprefix_descendant_translations(category_id, locale, old_permalink, new_permalink)
      descendants(category_id).each do |descendant_id, _base_permalink|
        row = connection.select_rows(sanitize(<<~SQL, descendant_id, locale)).first
          SELECT id, permalink FROM spree_category_translations
          WHERE spree_category_id = ? AND locale = ?
        SQL
        next if row.nil?

        translation_id, current = row
        next if current.blank? || !current.start_with?("#{old_permalink}/")

        move_translation(translation_id, current.sub("#{old_permalink}/", "#{new_permalink}/"))
      end
    end

    # Every (store, locale, permalink) appearing more than once, across all stores.
    # Shallowest first, for the same reason as #duplicate_groups.
    def translation_duplicate_groups
      rows = connection.select_rows(taxonomies_table? ? TRANSLATION_GROUPS_WITH_TAXONOMY_SQL : TRANSLATION_GROUPS_SQL)
      rows.sort_by { |_store_id, _locale, permalink| permalink.to_s.count('/') }
    end

    def translation_rows_for(store_id, locale, permalink)
      connection.select_rows(sanitize(<<~SQL, store_id, locale, permalink))
        SELECT tr.id, tr.spree_category_id
        FROM spree_category_translations tr
        INNER JOIN spree_categories c ON c.id = tr.spree_category_id
        #{taxonomy_join}
        WHERE #{effective_store_id} = ? AND tr.locale = ? AND tr.permalink = ?
        ORDER BY tr.id
      SQL
    end

    def translation_permalinks_for(store_id, locale)
      connection.select_values(sanitize(<<~SQL, store_id, locale)).compact.to_set
        SELECT tr.permalink
        FROM spree_category_translations tr
        INNER JOIN spree_categories c ON c.id = tr.spree_category_id
        #{taxonomy_join}
        WHERE #{effective_store_id} = ? AND tr.locale = ? AND tr.permalink IS NOT NULL
      SQL
    end

    # Walks the parent chain rather than using lft/rgt, which may be stale on rows
    # an installation has not rebuilt. One query per depth level, not per node.
    #
    # @return [Array<Array(Integer, String)>] (id, permalink) of every descendant
    def descendants(id)
      collected = []
      frontier = [id]

      until frontier.empty?
        rows = connection.select_rows(
          sanitize('SELECT id, permalink FROM spree_categories WHERE parent_id IN (?)', frontier)
        )
        break if rows.empty?

        collected.concat(rows)
        frontier = rows.map(&:first)
      end

      collected
    end
  end
end
