module Spree
  module Core
    module Search
      class Variant < Base
        def initialize(params)
          super
          params[:scope] ||= Spree::Variant.scoped
        end

        def search
          # Syntax inferred from http://ransack-demo.herokuapp.com/users/advanced_search
          query = { g: {} }
          grouping_count = 0
          fields = ['option_values_name', 'product_name', 'sku']
          params[:q].split(' ').each do |part|
            query[:g][grouping_count.to_s] = {
              m: 'or',
              c: {}
            }
            condition_count = 0
            fields.each do |field|
              query[:g][grouping_count.to_s][:c][condition_count.to_s] = {
                a: { '0' => { name: field } },
                p: 'cont',
                v: { '0' => { value: part } }
              }
              condition_count += 1
            end
            grouping_count += 1
          end

          result = params[:scope]
            .ransack(query)
            .result
            .page(params[:page])
            .per(params[:per_page])
        end
      end
    end
  end
end

