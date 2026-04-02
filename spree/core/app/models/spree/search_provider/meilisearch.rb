require 'pagy/toolbox/paginators/meilisearch'

module Spree
  module SearchProvider
    class Meilisearch < Base
      PREFIXED_ID_PATTERN = /\A[a-z]+_[A-Za-z0-9]+\z/
      ALLOWED_STATUSES = %w[active draft archived paused].freeze

      def self.indexing_required?
        true
      end

      def initialize(store)
        super
        require 'meilisearch'
      rescue LoadError
        raise LoadError, "Add `gem 'meilisearch'` to your Gemfile to use the Meilisearch search provider"
      end

      def search_and_filter(scope:, query: nil, filters: {}, sort: nil, page: 1, limit: 25)
        page = [page.to_i, 1].max
        limit = limit.to_i.clamp(1, 100)
        filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
        filters = (filters || {}).stringify_keys

        # Extract and group option values by option type for proper OR/AND semantics
        option_value_ids = extract_and_delete(filters, 'with_option_value_ids')
        grouped_options = group_option_values_by_type(Array(option_value_ids))

        base_conditions = build_filters(filters)
        option_conditions = build_grouped_option_conditions(grouped_options)
        all_conditions = base_conditions + option_conditions

        search_params = {
          filter: all_conditions,
          facets: facet_attributes,
          sort: build_sort(sort),
          offset: (page - 1) * limit,
          limit: limit
        }

        Rails.logger.debug { "[Meilisearch] index=#{index_name} query=#{query.inspect} #{search_params.compact.inspect}" }

        begin
          if grouped_options.any?
            # N+1 multi-search: 1 hit query + 1 disjunctive facet query per active option type
            queries = [{ indexUid: index_name, q: query.to_s, **search_params }]
            option_type_ids_ordered = grouped_options.keys
            option_type_ids_ordered.each do |option_type_id|
              without_this = build_grouped_option_conditions(grouped_options.except(option_type_id))
              queries << { indexUid: index_name, q: query.to_s, filter: base_conditions + without_this, facets: ['option_value_ids'], limit: 0 }
            end

            results = client.multi_search(queries)
            ms_result = results['results'][0]

            # Merge disjunctive counts per option type.
            # Each disjunctive query excluded one option type's filter.
            # Use that query's full option_value_ids distribution for that option type's values,
            # and the main query's distribution for everything else.
            main_ov_dist = ms_result.dig('facetDistribution', 'option_value_ids') || {}

            # Build a set of prefixed IDs per option type (including unselected values)
            # by looking up which option type each option value belongs to.
            all_ov_prefixed_ids = Set.new
            disjunctive_dists = {}
            results['results'][1..].each_with_index do |r, idx|
              dist = r.dig('facetDistribution', 'option_value_ids') || {}
              disjunctive_dists[option_type_ids_ordered[idx]] = dist
              all_ov_prefixed_ids.merge(dist.keys)
            end

            # Resolve which prefixed IDs belong to which option type
            all_raw_ids = all_ov_prefixed_ids.filter_map { |pid| Spree::OptionValue.decode_prefixed_id(pid) }
            ov_to_type = Spree::OptionValue.where(id: all_raw_ids).pluck(:id, :option_type_id).to_h
            prefixed_to_type = all_ov_prefixed_ids.each_with_object({}) do |pid, h|
              raw = Spree::OptionValue.decode_prefixed_id(pid)
              h[pid] = ov_to_type[raw] if raw
            end

            # Start with main query's distribution, overlay disjunctive counts for active option types
            merged_ov_dist = main_ov_dist.dup
            disjunctive_dists.each do |option_type_id, dist|
              dist.each do |pid, count|
                merged_ov_dist[pid] = count if prefixed_to_type[pid] == option_type_id
              end
            end

            facet_distribution = (ms_result['facetDistribution'] || {}).merge('option_value_ids' => merged_ov_dist)
          else
            ms_result = client.index(index_name).search(query.to_s, search_params)
            facet_distribution = ms_result['facetDistribution'] || {}
          end
        rescue ::Meilisearch::ApiError => e
          Rails.logger.warn { "[Meilisearch] Search failed: #{e.message}. Run `rake spree:search:reindex` to initialize the index." }
          Rails.error.report(e, handled: true, context: { index: index_name, query: query })
          return empty_result(scope, page, limit)
        end

        Rails.logger.debug { "[Meilisearch] #{ms_result['estimatedTotalHits']} hits in #{ms_result['processingTimeMs']}ms" }

        # Hits have composite prefixed_id (prod_abc_en_USD), extract product_id (prod_abc)
        product_prefixed_ids = ms_result['hits'].map { |h| h['product_id'] }.uniq
        raw_ids = product_prefixed_ids.filter_map { |pid| Spree::Product.decode_prefixed_id(pid) }

        # Intersect with AR scope for security/visibility, preserving Meilisearch sort order.
        products = if raw_ids.any?
                     records = scope.where(id: raw_ids).reorder(nil).index_by(&:id)
                     raw_ids.filter_map { |id| records[id] }
                   else
                     scope.none
                   end

        pagy = build_pagy(ms_result, page, limit)

        SearchResult.new(
          products: products,
          filters: build_facet_response(facet_distribution),
          sort_options: available_sort_options.map { |id| { id: id } },
          default_sort: 'manual',
          total_count: ms_result['estimatedTotalHits'] || 0,
          pagy: pagy
        )
      end

      def index(product)
        ensure_index_settings_once!
        documents = presenter_class.new(product, store).call
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
        scope ||= store.products
        ensure_index_settings!

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

      def presenter_class
        Spree::Dependencies.search_product_presenter_class
      end

      def client
        @client ||= ::Meilisearch::Client.new(
          ENV.fetch('MEILISEARCH_URL', 'http://localhost:7700'),
          ENV['MEILISEARCH_API_KEY']
        )
      end

      def index_name
        "#{store.code}_products"
      end

      def searchable_attributes
        %w[name description sku option_values category_names tags]
      end

      def filterable_attributes
        %w[product_id status in_stock store_ids locale currency discontinue_on price category_ids tags option_value_ids]
      end

      def sortable_attributes
        %w[name price created_at available_on units_sold_count]
      end

      def facet_attributes
        filterable_attributes
      end

      def available_sort_options
        %w[price -price name -name -available_on available_on best_selling]
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
        conditions = []
        conditions << "store_ids = '#{store.id}'"
        conditions << "status = 'active'"
        conditions << "locale = '#{locale.to_s.gsub(/[^a-zA-Z_-]/, '')}'"
        conditions << "currency = '#{currency.to_s.gsub(/[^A-Z]/, '')}'"
        conditions << "(discontinue_on = 0 OR discontinue_on > #{Time.current.to_i})"
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
        when 'with_option_value_ids'
          # Handled by grouped option conditions in search_and_filter — skip here
          nil
        end
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
      # OR within each option type, AND across option types.
      def build_grouped_option_conditions(grouped)
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
        when 'price'         then ['price:asc']
        when '-price'        then ['price:desc']
        when 'name'          then ['name:asc']
        when '-name'         then ['name:desc']
        when '-available_on' then ['available_on:desc']
        when 'available_on'  then ['available_on:asc']
        when 'best_selling'  then ['units_sold_count:desc']
        end
      end

      # Transform Meilisearch facetDistribution into standard filter response format.
      # Override in subclasses to add custom facets — call super and append.
      def build_facet_response(facet_distribution)
        facets = []
        facets << build_price_facet(facet_distribution['price']) if facet_distribution['price'].present?
        facets << build_availability_facet(facet_distribution['in_stock']) if facet_distribution['in_stock'].present?
        facets.concat(build_option_facets(facet_distribution['option_value_ids'])) if facet_distribution['option_value_ids'].present?
        facets << build_category_facet(facet_distribution['category_ids']) if facet_distribution['category_ids'].present?
        facets.compact
      end

      def build_price_facet(distribution)
        amounts = distribution.keys.map(&:to_f)
        {
          id: 'price',
          type: 'price_range',
          min: amounts.min,
          max: amounts.max,
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
          by_option_type[ot] << { id: ov.prefixed_id, name: ov.name, label: ov.label, position: ov.position, count: count }
        end

        by_option_type.map do |option_type, values|
          {
            id: option_type.prefixed_id,
            type: 'option',
            name: option_type.name,
            label: option_type.label,
            options: values.sort_by { |o| o[:position] }
          }
        end
      end

      def build_category_facet(distribution)
        prefixed_ids = distribution.keys
        raw_ids = prefixed_ids.filter_map { |pid| Spree::Taxon.decode_prefixed_id(pid) }
        categories = Spree::Taxon.where(id: raw_ids).index_by(&:prefixed_id)

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
          'totalHits' => ms_result['estimatedTotalHits'] || 0,
          'hitsPerPage' => limit,
          'page' => page
        })

        Pagy::MeilisearchPaginator.paginate(fake_result, {})
      end

      def empty_result(scope, page, limit)
        SearchResult.new(
          products: scope.none,
          filters: [],
          sort_options: available_sort_options.map { |id| { id: id } },
          default_sort: 'manual',
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
end
