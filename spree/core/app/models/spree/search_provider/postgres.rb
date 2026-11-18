module Spree
  module SearchProvider
    # PostgreSQL full-text search over product names and descriptions, the
    # default on PostgreSQL. Filters, facets, sorting and pagination are the
    # Database provider's; only the text match and the default order differ.
    #
    # Everything +Product.search+ matches (part of a name or SKU, searchable
    # custom fields) still matches, ranked after the full-text hits. With the
    # +pg_trgm+ extension enabled, a query that matches nothing falls back to
    # the names closest to it, so a misspelling still finds the product.
    class Postgres < Database
      # Request language => text search configuration, for the configurations
      # every supported PostgreSQL version ships. Anything else uses +simple+,
      # which matches words as written, without stemming.
      LANGUAGES = {
        'ar' => 'arabic', 'da' => 'danish', 'de' => 'german', 'el' => 'greek', 'en' => 'english',
        'es' => 'spanish', 'fi' => 'finnish', 'fr' => 'french', 'ga' => 'irish', 'hu' => 'hungarian',
        'id' => 'indonesian', 'it' => 'italian', 'lt' => 'lithuanian', 'nb' => 'norwegian', 'ne' => 'nepali',
        'nl' => 'dutch', 'no' => 'norwegian', 'pt' => 'portuguese', 'ro' => 'romanian', 'ru' => 'russian',
        'sv' => 'swedish', 'ta' => 'tamil', 'tr' => 'turkish'
      }.freeze
      # Longer queries skip full-text search and the typo fallback, whose cost
      # grows with the query, and keep only the plain match on the whole text.
      MAX_QUERY_LENGTH = 200
      MAX_TYPO_QUERY_LENGTH = 64
      # Lowest pg_trgm word similarity at which a name counts as a misspelling
      # of the query. A missing or wrong letter scores 0.5 or more; unrelated
      # names that merely share a few letters stay below it.
      TYPO_SIMILARITY = 0.5
      # Created by the +add_product_search_indexes+ migration.
      INDEXES = %w[index_spree_products_on_search_vector_english index_spree_product_translations_on_search_vector_english].freeze

      class << self
        # Whether a misspelled query falls back to the closest product names.
        # Read once per process: pg_trgm is enabled by a migration or a
        # deploy-time task, never while the application is serving requests.
        #
        # @return [Boolean]
        def typo_tolerance?
          return @typo_tolerance if defined?(@typo_tolerance)

          # Asks whether the function can be called, not whether the extension
          # is enabled: pg_trgm in a schema off the search path, or closed to
          # this role, is enabled yet unusable.
          @typo_tolerance = Spree::Product.connection.select_value(
            "SELECT has_function_privilege(to_regprocedure('word_similarity(text,text)'), 'EXECUTE')"
          ) == true
        end

        # @return [Array<String>] names of the search indexes this database lacks
        def missing_indexes
          connection = Spree::Product.connection
          usable = [Spree::Product, Spree::Product::Translation].flat_map do |model|
            connection.indexes(model.table_name).select(&:valid?).map(&:name)
          end
          INDEXES - usable
        end

        def diagnostics
          { 'Typo tolerance' => -> { typo_tolerance? }, 'Missing indexes' => -> { missing_indexes } }
        end
      end

      def search_and_filter(query: nil, **)
        @ranked_query = query
        super
      end

      private

      def apply_search_and_filters(scope, query: nil, filters: {})
        filtered = super(scope, query: nil, filters: filters)
        return filtered if query.blank?

        typed = typed_ids_sql(query)
        if self.class.typo_tolerance? && query.to_s.length <= MAX_TYPO_QUERY_LENGTH
          # Misspellings are a fallback: offered only when nothing the shopper
          # may see matches as typed, whatever the filters, so they never pad
          # out a search that found what it asked for.
          seen = scope.where(Spree::Product.arel_table[:id].in(Arel.sql(typed))).except(:includes, :preload, :order).select('1').to_sql
          closest = product_ids_sql { |table| "#{similarity_sql(table, query)} >= #{TYPO_SIMILARITY}" }.join(' UNION ')
          typed = "#{typed} UNION SELECT id FROM (#{closest}) closest WHERE NOT EXISTS (#{seen})"
        end

        filtered.where(Spree::Product.arel_table[:id].in(Arel.sql(typed)))
      end

      def apply_sort(scope, sort, grouping: nil)
        # 'manual' with no category or collection to order within has no order
        # of its own, so it ranks as well.
        ranked = sort.blank? || (sort == 'manual' && grouping.nil?)
        return super if !ranked || query_words(@ranked_query).empty?

        products = Spree::Product.arel_table
        scope = scope.select(products[Arel.star]).
                select("#{best_sql { |table| rank_sql(table, @ranked_query) }} AS search_rank")
        order = [Arel.sql('search_rank DESC')]
        if self.class.typo_tolerance?
          scope = scope.select("#{best_sql { |table| similarity_sql(table, @ranked_query) }} AS search_similarity")
          order << Arel.sql('search_similarity DESC')
        end
        scope.reorder(*order, products[:id].asc)
      end

      # One id list per way a product can match as typed, so each part reads
      # its own index instead of the planner scanning every product for an OR.
      def typed_ids_sql(query)
        parts = [Spree::Product.search(query, store, audience: audience).reorder(nil).select(:id).to_sql]
        parts += product_ids_sql { |table| "#{vector_sql(table)} @@ #{tsquery_sql(table, query)}" } if query_words(query).any?
        parts.join(' UNION ')
      end

      # Product ids whose own row meets the condition, plus those whose
      # translation for the current locale does.
      def product_ids_sql
        queries = ["SELECT #{products_table}.id FROM #{products_table} WHERE #{yield products_table}"]
        return queries unless Spree.use_translations?

        queries << "SELECT #{translations_table}.spree_product_id FROM #{translations_table} " \
                   "WHERE #{current_translation_sql} AND #{yield translations_table}"
      end

      # The better of a score on the product's own row and on its translation
      # for the current locale.
      def best_sql
        return yield(products_table) unless Spree.use_translations?

        "GREATEST(#{yield products_table}, COALESCE((SELECT #{yield translations_table} FROM #{translations_table} " \
          "WHERE #{translations_table}.spree_product_id = #{products_table}.id AND #{current_translation_sql} LIMIT 1), 0))"
      end

      def current_translation_sql
        "#{translations_table}.locale = #{quote(Mobility.locale.to_s)} AND #{translations_table}.deleted_at IS NULL"
      end

      # Must stay identical to the expression the search indexes are built on,
      # or PostgreSQL stops using them.
      def vector_sql(table)
        "(setweight(to_tsvector(#{configuration(table)}, coalesce(#{table}.name, '')), 'A') || " \
          "setweight(to_tsvector(#{configuration(table)}, coalesce(#{table}.description, '')), 'B'))"
      end

      # Zero unless every word matches: ts_rank alone also scores a partial
      # match, which would lift a SKU-only hit above a full one.
      def rank_sql(table, query)
        tsquery = tsquery_sql(table, query)
        "CASE WHEN #{vector_sql(table)} @@ #{tsquery} THEN ts_rank(#{vector_sql(table)}, #{tsquery}) ELSE 0 END"
      end

      def similarity_sql(table, query)
        "word_similarity(#{quote(query.to_s.downcase)}, lower(coalesce(#{table}.name, '')))"
      end

      # Every word must match; the last one matches as a prefix, so results
      # appear while the shopper is still typing it.
      def tsquery_sql(table, query)
        "to_tsquery(#{configuration(table)}, #{quote("#{query_words(query).join(' & ')}:*")})"
      end

      # A decimal stays one word ("1.5"), the way PostgreSQL reads it in a name.
      def query_words(query)
        return [] if query.to_s.length > MAX_QUERY_LENGTH

        query.to_s.scan(/[[:digit:]]+(?:\.[[:digit:]]+)+|[[:alnum:]]+/)
      end

      # Each row is read in the language it is written in: the product's own
      # row holds the store's content language, a translation its own locale.
      def configuration(table)
        locale = table == products_table ? Spree::Current.content_locale : Mobility.locale
        quote(LANGUAGES.fetch(Spree::Locale.new(code: locale).language_code, 'simple'))
      end

      def products_table
        Spree::Product.quoted_table_name
      end

      def translations_table
        Spree::Product::Translation.quoted_table_name
      end

      def quote(value)
        Spree::Product.connection.quote(value)
      end
    end
  end
end
