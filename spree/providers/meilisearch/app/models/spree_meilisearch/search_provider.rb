module SpreeMeilisearch
  # Product search, filtering and faceted navigation backed by a Meilisearch
  # index — one index per store, holding the documents
  # SpreeMeilisearch::ProductPresenter builds. Results are always intersected
  # with the caller's ActiveRecord scope, so a stale index can never widen
  # what a customer is allowed to see.
  class SearchProvider < Spree::SearchProvider::Base
    PREFIXED_ID_PATTERN = /\A[a-z]+_[A-Za-z0-9]+\z/
    ALLOWED_STATUSES = %w[active draft archived paused].freeze
    BUILT_IN_FILTERABLE_ATTRIBUTES = %w[product_id status in_stock preorder store_ids channel_ids locale currency available_on discontinue_on price category_ids collection_ids grouping_id tags option_value_ids option_value_combination_ids].freeze
    CUSTOM_FIELD_RANGE_OPERATORS = { 'gt' => '>', 'gteq' => '>=', 'lt' => '<', 'lteq' => '<=' }.freeze

    def self.indexing_required?
      true
    end

    def search_and_filter(scope:, query: nil, filters: {}, sort: nil, page: 1, limit: 25)
      page = [page.to_i, 1].max
      limit = limit.to_i.clamp(1, 100)

      filters = normalize_filters(filters)
      sort, filters = resolve_manual_sort(sort, filters)

      ms_result, _ = execute_search(query: query, filters: filters, sort: sort, page: page, limit: limit)
      return empty_result(scope, page, limit) unless ms_result

      # Hits have composite prefixed_id (prod_abc_en_USD), extract product_id (prod_abc)
      product_prefixed_ids = ms_result['hits'].map { |h| h['product_id'] }.uniq
      raw_ids = product_prefixed_ids.filter_map { |pid| Spree::Product.decode_prefixed_id(pid) }

      # Intersect with AR scope for security/visibility, preserving Meilisearch sort order.
      # When the index could only pre-filter the option values, the database
      # answers the same-variant question exactly here.
      scope = scope.with_option_value_ids(@inexact_option_value_ids) if @inexact_option_value_ids.present?
      products = if raw_ids.any?
                   records = scope.where(id: raw_ids).reorder(nil).index_by(&:id)
                   raw_ids.filter_map { |id| records[id] }
                 else
                   scope.none
                 end

      pagy = build_pagy(ms_result, page, limit)

      Spree::SearchProvider::SearchResult.new(
        products: products,
        total_count: ms_result['totalHits'] || 0,
        pagy: pagy
      )
    end

    def filters(scope:, query: nil, filters: {})
      collection = filters.is_a?(Hash) ? (filters['_collection'] || filters[:_collection]) : nil
      default_sort = collection ? to_api_sort(collection.sort_order) : 'manual'

      ms_result, facet_distribution = execute_search(query: query, filters: filters, sort: nil, page: 1, limit: 0, return_facets: true)

      unless ms_result
        return Spree::SearchProvider::FiltersResult.new(
          filters: [],
          sort_options: built_in_and_custom_field_sort_options,
          default_sort: default_sort,
          total_count: 0
        )
      end

      Spree::SearchProvider::FiltersResult.new(
        filters: build_facet_response(facet_distribution, ms_result['facetStats'] || {}),
        sort_options: built_in_and_custom_field_sort_options,
        default_sort: default_sort,
        total_count: ms_result['totalHits'] || 0
      )
    end

    def index(product)
      ensure_index_settings_once!
      documents = presenter_class.new(product, store).call
      # Delete first: membership docs use grouping-specific ids, so a product
      # that left a grouping would otherwise leave an orphaned stale doc.
      remove_by_id(product.prefixed_id)
      client.index(index_name).add_documents(documents, 'id')
    end

    def remove(product)
      remove_by_id(product.prefixed_id)
    end

    def index_batch(documents)
      return if documents.empty?

      client.index(index_name).add_documents(documents, 'id')
    end

    # Remove all documents for a product by its prefixed_id (e.g. 'prod_abc')
    def remove_by_id(prefixed_id)
      filter = "product_id = '#{sanitize_prefixed_id(prefixed_id)}'"
      client.index(index_name).delete_documents(filter: filter)
    rescue ::Meilisearch::ApiError => e
      raise unless e.http_code == 404
    end

    def reindex(scope = nil)
      full_reindex = scope.nil?
      scope ||= store.products
      @custom_field_schema = Spree::SearchProvider::CustomFieldSchema.new
      ensure_index_settings!

      # On a full reindex, clear first so stale docs (e.g. membership docs for
      # removed groupings) don't linger; a scoped reindex keeps upsert semantics.
      client.index(index_name).delete_all_documents if full_reindex

      indexed = 0
      scope.reorder(id: :asc)
           .preload_associations_lazily
           .find_in_batches(batch_size: 500) do |batch|
        documents = batch.flat_map { |product| presenter_class.new(product, store).call }
        next if documents.empty?

        index_batch(documents)
        indexed += documents.size

        Rails.logger.info { "[Meilisearch] Enqueued #{documents.size} documents (#{indexed} total) for #{index_name}" }
      end

      Rails.logger.info { "[Meilisearch] Reindex complete: #{indexed} documents enqueued for #{index_name}" }
      indexed
    end

    # Configure index settings for filtering, sorting, and faceting.
    # Called automatically by reindex, but can be called separately.
    # Waits for all settings tasks to complete before returning so that
    # subsequent add_documents calls use the correct filterable/sortable attributes.
    def ensure_index_settings!
      index = client.index(index_name)
      tasks = []
      tasks << index.update_filterable_attributes(filterable_attributes)
      tasks << index.update_sortable_attributes(sortable_attributes)
      tasks << index.update_searchable_attributes(searchable_attributes)
      tasks << index.update_distinct_attribute(distinct_attribute)
      tasks.each { |task| task&.await }
      @index_settings_configured = true
    end

    # Lightweight guard — configures index settings once per provider instance.
    # Meilisearch settings updates are idempotent, so repeated calls are safe
    # but we avoid the overhead by memoizing.
    def ensure_index_settings_once!
      return if @index_settings_configured

      ensure_index_settings!
    end

    private

    # Normalize incoming filters to a plain, string-keyed Hash.
    def normalize_filters(filters)
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      (filters || {}).stringify_keys
    end

    # Manual/position sort. When a single grouping is being viewed (in_collection
    # or in_category) and the effective sort is 'manual' — either requested, or
    # the grouping-page default (blank ⇒ manual) — query the per-grouping
    # membership docs: swap the membership filter for `grouping_id` and sort by
    # the scalar `position`. Without a grouping, 'manual' has nothing to order by,
    # so it falls back to Meilisearch default ranking.
    def resolve_manual_sort(sort, filters)
      grouping_id = filters['in_collection'] || filters['in_category']
      grouping_id = nil unless valid_prefixed_id?(grouping_id)
      sort = 'manual' if sort.blank? && grouping_id

      if sort == 'manual' && grouping_id
        filters = filters.except('in_collection', 'in_category').merge('grouping_id' => grouping_id)
      elsif sort == 'manual'
        sort = nil
      end

      [sort, filters]
    end

    # Execute a Meilisearch query. Returns [ms_result, facet_distribution].
    # facet_distribution is empty when return_facets is false. Returns nil on API error.
    def execute_search(query:, filters:, sort:, page:, limit:, return_facets: false)
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters = (filters || {}).stringify_keys

      option_value_ids = extract_and_delete(filters, 'with_option_value_ids')
      grouped_options = group_option_values_by_type(Array(option_value_ids))
      # Handed back to the caller so it can narrow the record scope exactly
      # when the index cannot — see build_grouped_option_conditions.
      @inexact_option_value_ids = option_exact?(grouped_options) ? nil : Array(option_value_ids)

      base_conditions = build_filters(filters)
      option_conditions = build_grouped_option_conditions(grouped_options)
      all_conditions = base_conditions + option_conditions

      # Page-based (exhaustive) pagination — REQUIRED so `distinct` collapses
      # totalHits and facetDistribution to per-product counts. The offset/limit
      # ("estimatedTotalHits") mode does NOT apply distinct to the count or
      # facets, which over-counts the duplicated per-grouping membership docs.
      search_params = {
        filter: all_conditions,
        facets: return_facets ? facet_attributes : nil,
        sort: build_sort(sort),
        page: page,
        hitsPerPage: limit
      }.compact

      Rails.logger.debug { "[Meilisearch] index=#{index_name} query=#{query.inspect} #{search_params.compact.inspect}" }

      settings_refreshed = false
      begin
        if return_facets && grouped_options.any?
          queries = [{ indexUid: index_name, q: query.to_s, **search_params }]
          option_type_ids_ordered = grouped_options.keys
          option_type_ids_ordered.each do |option_type_id|
            without_this = build_grouped_option_conditions(grouped_options.except(option_type_id))
            queries << { indexUid: index_name, q: query.to_s, filter: base_conditions + without_this, facets: ['option_value_ids'], page: 1, hitsPerPage: 0 }
          end

          results = client.multi_search(queries)
          ms_result = results['results'][0]
          facet_distribution = merge_disjunctive_facets(ms_result, results['results'][1..], option_type_ids_ordered)
        else
          ms_result = client.index(index_name).search(query.to_s, search_params)
          facet_distribution = ms_result['facetDistribution'] || {}
        end
      rescue ::Meilisearch::ApiError => e
        # Self-heal when a newly added filterable attribute (e.g. `preorder`)
        # is referenced before the index settings were refreshed — otherwise
        # every search on an upgraded store returns empty until a reindex or
        # the next product write.
        if %w[invalid_search_filter invalid_search_sort].include?(e.code) && !settings_refreshed
          settings_refreshed = true
          ensure_index_settings!
          retry
        end

        Rails.logger.warn { "[Meilisearch] Search failed: #{e.message}. Run `rake spree:search:reindex` to initialize the index." }
        Rails.error.report(e, handled: true, context: { index: index_name, query: query })
        return nil
      end

      Rails.logger.debug { "[Meilisearch] #{ms_result['totalHits']} hits in #{ms_result['processingTimeMs']}ms" }

      [ms_result, facet_distribution]
    end

    def merge_disjunctive_facets(ms_result, disjunctive_results, option_type_ids_ordered)
      main_ov_dist = ms_result.dig('facetDistribution', 'option_value_ids') || {}

      all_ov_prefixed_ids = Set.new
      disjunctive_dists = {}
      disjunctive_results.each_with_index do |r, idx|
        dist = r.dig('facetDistribution', 'option_value_ids') || {}
        disjunctive_dists[option_type_ids_ordered[idx]] = dist
        all_ov_prefixed_ids.merge(dist.keys)
      end

      all_raw_ids = all_ov_prefixed_ids.filter_map { |pid| Spree::OptionValue.decode_prefixed_id(pid) }
      ov_to_type = Spree::OptionValue.where(id: all_raw_ids).pluck(:id, :option_type_id).to_h
      prefixed_to_type = all_ov_prefixed_ids.each_with_object({}) do |pid, h|
        raw = Spree::OptionValue.decode_prefixed_id(pid)
        h[pid] = ov_to_type[raw] if raw
      end

      merged_ov_dist = main_ov_dist.dup
      disjunctive_dists.each do |option_type_id, dist|
        dist.each do |pid, count|
          merged_ov_dist[pid] = count if prefixed_to_type[pid] == option_type_id
        end
      end

      (ms_result['facetDistribution'] || {}).merge('option_value_ids' => merged_ov_dist)
    end

    def presenter_class
      Spree::Dependencies.search_product_presenter_class
    end

    def client
      @client ||= SpreeMeilisearch.client
    end

    def index_name
      "#{store.code}_products"
    end

    def searchable_attributes
      %w[name description sku option_values category_names tags] + custom_field_schema.searchable_attribute_keys
    end

    def filterable_attributes
      BUILT_IN_FILTERABLE_ATTRIBUTES + custom_field_schema.filterable_attribute_keys
    end

    def sortable_attributes
      %w[name price created_at available_on units_sold_count position] + custom_field_schema.sortable_attribute_keys
    end

    # Facets stay built-in only — cf_* distributions aren't consumed by
    # +build_facet_response+, so requesting them would be wasted work.
    def facet_attributes
      BUILT_IN_FILTERABLE_ATTRIBUTES
    end

    # Collapses the per-grouping membership docs to one row per product on
    # non-grouping queries (shop-all, search, non-manual sorts). Facet counts
    # and totals honor distinct on Meilisearch >= 1.40.
    def distinct_attribute
      'product_id'
    end

    # Sourced from Spree::Collection::SORT_ORDERS (matching FiltersAggregator) so
    # both providers advertise identical options — including 'manual'.
    def available_sort_options
      Spree::Collection::SORT_ORDERS.map { |sort_order| to_api_sort(sort_order) } + custom_field_schema.sort_ids
    end

    # Converts internal sort format ('price asc') to API format ('price', '-price').
    def to_api_sort(sort_value)
      return sort_value unless sort_value.to_s.include?(' ')

      field, direction = sort_value.split(' ', 2)
      direction == 'desc' ? "-#{field}" : field
    end

    def built_in_and_custom_field_sort_options
      Spree::Collection::SORT_ORDERS.map { |sort_order| { id: to_api_sort(sort_order), label: nil } } +
        custom_field_schema.sort_options
    end

    # Build Meilisearch filter conditions from API params.
    # Combines system scoping (always applied) with user-facing filters.
    def build_filters(filters)
      conditions = system_filter_conditions
      conditions.concat(user_filter_conditions(filters))
      conditions
    end

    # System scoping — always applied. Rarely overridden.
    # Mirrors the AR scope: store.products.active(currency) with locale.
    def system_filter_conditions
      now = Time.current
      conditions = []
      conditions << "store_ids = '#{store.id}'"
      conditions << "channel_ids = '#{Spree::Current.channel.id}'" if Spree::Current.channel
      conditions << "status = 'active'"
      conditions << "locale = '#{locale.to_s.gsub(/[^a-zA-Z_-]/, '')}'"
      conditions << "currency = '#{currency.to_s.gsub(/[^A-Z]/, '')}'"
      # Exclude future-dated products — mirrors
      # +Product.available(Time.current, include_preorderable: true)+. ISO 8601
      # strings sort lexicographically in chronological order, so the string
      # compare is sound; +NOT EXISTS+/+IS NULL+ keep the available_on clause
      # backward-compatible with legacy docs. The trailing +preorder = true+
      # keeps scheduled "coming soon" pre-orders searchable before their
      # publish date. It filters on the new +preorder+ attribute, so a
      # +rake spree:search:reindex+ (or the next product write, which refreshes
      # the index settings) is required after deploy before it takes effect.
      conditions << "(available_on NOT EXISTS OR available_on IS NULL OR available_on <= '#{now.iso8601}' OR preorder = true)"
      conditions << "(discontinue_on = 0 OR discontinue_on > #{now.to_i})"
      conditions
    end

    # User-facing filters — override to add custom filter pre/post processing.
    def user_filter_conditions(filters)
      conditions = []
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      return conditions if filters.blank?

      filters.each do |key, value|
        next if value.blank?

        condition = build_filter_condition(key.to_s, value)
        if condition.is_a?(Array)
          conditions.concat(condition)
        elsif condition
          conditions << condition
        end
      end

      conditions
    end

    # Translate a single Ransack-style filter param into Meilisearch filter syntax.
    # Override in subclasses to handle custom filter keys — call super for built-in filters.
    def build_filter_condition(key, value)
      case key
      when 'price_gte'
        "price >= #{value.to_f}"
      when 'price_lte'
        "price <= #{value.to_f}"
      when 'in_stock'
        'in_stock = true' if value.to_s != '0'
      when 'out_of_stock'
        'in_stock = false' if value.to_s != '0'
      when 'in_category'
        "category_ids = '#{sanitize_prefixed_id(value)}'" if valid_prefixed_id?(value)
      when 'in_categories'
        parts = Array(value).filter_map { |id| "category_ids = '#{sanitize_prefixed_id(id)}'" if valid_prefixed_id?(id) }
        parts.length > 1 ? "(#{parts.join(' OR ')})" : parts.first
      when 'in_collection'
        "collection_ids = '#{sanitize_prefixed_id(value)}'" if valid_prefixed_id?(value)
      when 'grouping_id'
        "grouping_id = '#{sanitize_prefixed_id(value)}'" if valid_prefixed_id?(value)
      when 'with_option_value_ids'
        # Handled by grouped option conditions in search_and_filter — skip here
        nil
      else
        custom_field_filter_condition(key, value)
      end
    end

    # Meilisearch has stable filter operators for equality, ranges, and
    # EXISTS — but no string contains/starts/ends (CONTAINS is still
    # experimental), so those predicates are ignored here. The Database
    # provider supports the full predicate set.
    def custom_field_filter_condition(key, value)
      parsed = custom_field_schema.parse_filter(key)
      return nil unless parsed

      attribute = parsed[:definition].filter_key
      numeric = parsed[:definition].field_type == 'number'

      case parsed[:predicate]
      when 'present'
        "#{attribute} EXISTS"
      when 'blank'
        "#{attribute} NOT EXISTS"
      when 'eq', 'not_eq'
        operator = parsed[:predicate] == 'eq' ? '=' : '!='
        formatted = format_custom_field_filter_value(value, numeric)
        formatted && "#{attribute} #{operator} #{formatted}"
      when *CUSTOM_FIELD_RANGE_OPERATORS.keys
        return nil unless numeric

        formatted = format_custom_field_filter_value(value, numeric)
        formatted && "#{attribute} #{CUSTOM_FIELD_RANGE_OPERATORS[parsed[:predicate]]} #{formatted}"
      end
    end

    def format_custom_field_filter_value(value, numeric)
      if numeric
        Float(value.to_s, exception: false)&.to_s
      else
        "'#{escape_filter_string(value)}'"
      end
    end

    def escape_filter_string(value)
      value.to_s.gsub('\\') { '\\\\' }.gsub("'") { "\\'" }
    end

    # Group prefixed option value IDs by option type (single DB query).
    # Returns { option_type_id => ['optval_abc', 'optval_def'], ... }
    def group_option_values_by_type(prefixed_ids)
      prefixed_ids = prefixed_ids.flatten.compact.select { |id| valid_prefixed_id?(id) }
      return {} if prefixed_ids.empty?

      raw_ids = prefixed_ids.filter_map { |id| Spree::OptionValue.decode_prefixed_id(id) }
      Spree::OptionValue.where(id: raw_ids).group_by(&:option_type_id).transform_values { |ovs| ovs.map(&:prefixed_id) }
    end

    # Build Meilisearch filter conditions from grouped option values.
    # OR within each option type, AND across option types — and the AND has to
    # hold within ONE variant, matching Spree::Product.with_option_value_ids.
    #
    # A single axis reads straight off the value union. Two or more axes ask
    # instead for a combination token the presenter wrote per variant, so "blue
    # AND XL" cannot be satisfied by a blue small sitting beside a red XL. One
    # token per whole combination rather than per pair: pairs can each hold on
    # a different variant while no variant carries them all.
    #
    # When the tokens cannot answer exactly — a filter naming more axes than
    # the presenter indexed, or a swapped-in presenter that writes no tokens at
    # all — this falls back to the per-axis union, a superset. On its own that
    # superset would re-open the cross-variant bug, so `search_and_filter`
    # detects the fallback and narrows the ActiveRecord scope through
    # `Spree::Product.with_option_value_ids` before intersecting: the database
    # gives the exact answer, Meilisearch only pre-filters. Rare by
    # construction — MAX_COMBINATION_AXES covers any product a catalog
    # realistically facets by — so its one cost, a page that can come back
    # short, is accepted rather than designed around.
    def build_grouped_option_conditions(grouped)
      return single_axis_option_conditions(grouped) if grouped.size < 2
      return single_axis_option_conditions(grouped) unless combination_tokens_cover?(grouped)

      combinations = grouped.values[0].product(*grouped.values[1..])
      tokens = combinations.map { |combination| option_combination_condition(combination) }
      [tokens.length > 1 ? "(#{tokens.join(' OR ')})" : tokens.first]
    end

    # Whether the index actually holds a token for a filter this wide.
    def combination_tokens_cover?(grouped)
      max = max_combination_axes
      !max.nil? && grouped.size <= max
    end

    # Whether the option conditions sent to Meilisearch answer the filter
    # exactly. A single axis always does (the union IS the answer there); more
    # need the combination tokens to be present for that width.
    def option_exact?(grouped)
      grouped.size < 2 || combination_tokens_cover?(grouped)
    end

    # Each id is sanitized on its own — the separator is not part of an id and
    # the sanitizer would strip it.
    def option_combination_condition(prefixed_ids)
      token = prefixed_ids.map { |id| sanitize_prefixed_id(id) }.sort.join('|')
      "option_value_combination_ids = '#{token}'"
    end

    # Read off the presenter, since it is what decides how deep the tokens go.
    # Nil when a swapped-in presenter declares nothing: it writes no tokens, so
    # filtering on them would match nothing at all.
    #
    # @return [Integer, nil]
    def max_combination_axes
      return unless presenter_class.const_defined?(:MAX_COMBINATION_AXES)

      presenter_class::MAX_COMBINATION_AXES
    end

    def single_axis_option_conditions(grouped)
      grouped.map do |_, prefixed_ids|
        parts = prefixed_ids.map { |id| "option_value_ids = '#{sanitize_prefixed_id(id)}'" }
        parts.length > 1 ? "(#{parts.join(' OR ')})" : parts.first
      end
    end

    def extract_and_delete(hash, *keys)
      keys.each do |key|
        value = hash.delete(key) || hash.delete(key.to_sym)
        return value if value.present?
      end
      nil
    end

    # Sort param to Meilisearch sort syntax.
    # Override in subclasses to handle custom sort keys — call super for built-in sorts.
    def build_sort(sort)
      return nil if sort.blank?

      sort_mapping(sort)
    end

    # Map a sort param to Meilisearch sort syntax.
    # Override in subclasses to add custom sorts — call super for built-in sorts.
    def sort_mapping(sort)
      case sort
      when 'manual'        then ['position:asc']
      when 'price'         then ['price:asc']
      when '-price'        then ['price:desc']
      when 'name'          then ['name:asc']
      when '-name'         then ['name:desc']
      when '-available_on' then ['available_on:desc']
      when 'available_on'  then ['available_on:asc']
      when 'best_selling'  then ['units_sold_count:desc']
      else
        parsed = custom_field_schema.parse_sort(sort)
        parsed && ["#{parsed[:attribute]}:#{parsed[:direction]}"]
      end
    end

    # Transform Meilisearch facetDistribution into standard filter response format.
    # Override in subclasses to add custom facets — call super and append.
    def build_facet_response(facet_distribution, facet_stats = {})
      facets = []
      facets << build_price_facet(facet_distribution['price'], facet_stats['price']) if facet_distribution['price'].present?
      facets << build_availability_facet(facet_distribution['in_stock']) if facet_distribution['in_stock'].present?
      facets.concat(build_option_facets(facet_distribution['option_value_ids'])) if facet_distribution['option_value_ids'].present?
      facets << build_category_facet(facet_distribution['category_ids']) if facet_distribution['category_ids'].present?
      facets.compact
    end

    # Bounds come from facetStats, which Meilisearch computes across every
    # matching document. The distribution is capped at maxValuesPerFacet (100
    # by default), so deriving min/max from its keys understates the range on
    # any result set with more distinct prices than that.
    def build_price_facet(distribution, stats = nil)
      amounts = distribution.keys.map(&:to_f)
      {
        id: 'price',
        type: 'price_range',
        min: stats ? stats['min'].to_f : amounts.min,
        max: stats ? stats['max'].to_f : amounts.max,
        currency: currency
      }
    end

    def build_availability_facet(distribution)
      {
        id: 'availability',
        type: 'availability',
        options: [
          { id: 'in_stock', count: distribution['true'] || 0 },
          { id: 'out_of_stock', count: distribution['false'] || 0 }
        ]
      }
    end

    def build_option_facets(distribution)
      prefixed_ids = distribution.keys
      raw_ids = prefixed_ids.filter_map { |pid| Spree::OptionValue.decode_prefixed_id(pid) }
      option_values = Spree::OptionValue.where(id: raw_ids).includes(:option_type).preload_associations_lazily.index_by(&:prefixed_id)

      # Group by option type
      by_option_type = {}
      distribution.each do |ov_prefixed_id, count|
        ov = option_values[ov_prefixed_id]
        next unless ov

        ot = ov.option_type
        by_option_type[ot] ||= []
        by_option_type[ot] << {
          id: ov.prefixed_id, name: ov.name, label: ov.label, position: ov.position,
          color_code: ov.color_code,
          image_url: ov.image.attached? ? Rails.application.routes.url_helpers.cdn_image_url(ov.image) : nil,
          count: count
        }
      end

      by_option_type.map do |option_type, values|
        {
          id: option_type.prefixed_id,
          type: 'option',
          name: option_type.name,
          label: option_type.label,
          kind: option_type.kind,
          options: values.sort_by { |o| o[:position] }
        }
      end
    end

    def build_category_facet(distribution)
      prefixed_ids = distribution.keys
      raw_ids = prefixed_ids.filter_map { |pid| Spree::Category.decode_prefixed_id(pid) }
      categories = Spree::Category.where(id: raw_ids).index_by(&:prefixed_id)

      {
        id: 'categories',
        type: 'category',
        options: distribution.filter_map do |prefixed_id, count|
          cat = categories[prefixed_id]
          next unless cat

          { id: cat.prefixed_id, name: cat.name, permalink: cat.permalink, count: count }
        end
      }
    end

    def build_pagy(ms_result, page, limit)
      fake_result = Struct.new(:raw_answer).new({
        'totalHits' => ms_result['totalHits'] || 0,
        'hitsPerPage' => limit,
        'page' => page
      })

      Pagy::MeilisearchPaginator.paginate(fake_result, {})
    end

    def empty_result(scope, page, limit)
      Spree::SearchProvider::SearchResult.new(
        products: scope.none,
        total_count: 0,
        pagy: Pagy::Offset.new(count: 0, page: page, limit: limit)
      )
    end

    def valid_prefixed_id?(value)
      value.to_s.match?(PREFIXED_ID_PATTERN)
    end

    def sanitize_prefixed_id(value)
      value.to_s.gsub(/[^a-zA-Z0-9_]/, '')
    end
  end
end
