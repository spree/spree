module Spree
  module Core
    module Search
      class Variant < Base
        SEARCH_FIELDS = %w(option_values_name product_name sku)

        def initialize(params)
          super
          params[:scope] ||= Spree::Variant.all
        end

        def search
          params[:scope].ransack(query).result.page(params[:page]).per(params[:per_page])
        end

        private

        def query_strings
          (params[:q] || '').split(' ')
        end

        def query
          { g: query_groups }
        end

        def query_groups
          query_strings.map.with_index { |subquery, index| [index.to_s, query_group(subquery)] }.to_h
        end

        def query_group(subquery)
          {
            m: 'or',
            c: conditions(subquery)
          }
        end

        def conditions(subquery)
          SEARCH_FIELDS.map.with_index { |search_field, index| [index.to_s, condition(search_field, subquery)] }.to_h
        end

        def condition(search_field, subquery)
          {
            a: { '0' => { name: search_field } },
            p: 'cont',
            v: { '0' => { value: subquery } }
          }
        end
      end
    end
  end
end
