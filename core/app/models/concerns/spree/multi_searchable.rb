module Spree
  module MultiSearchable
    extend ActiveSupport::Concern

    included do
      def self.sanitize_query_for_multi_search(query)
        ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase.strip)
      end

      def self.multi_search_condition(model_class, attribute, query)
        encrypted_attributes = model_class.encrypted_attributes.presence || []

        if encrypted_attributes.include?(attribute.to_sym)
          model_class.arel_table[attribute.to_sym].eq(query)
        else
          model_class.arel_table[attribute.to_sym].lower.matches("%#{query}%")
        end
      end
    end
  end
end
