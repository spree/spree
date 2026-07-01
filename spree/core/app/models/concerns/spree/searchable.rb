module Spree
  module Searchable
    extend ActiveSupport::Concern

    included do
      def self.sanitize_query_for_search(query)
        ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase.strip)
      end

      def self.search_condition(model_class, attribute, query)
        encrypted_attributes = model_class.encrypted_attributes.presence || []

        if encrypted_attributes.include?(attribute.to_sym)
          # Encrypted columns can only be compared by equality — wildcard
          # LIKE escapes would prevent the row from matching itself, so pass
          # the raw query straight through.
          model_class.arel_table[attribute.to_sym].eq(query.to_s.strip)
        else
          # Plain columns use case-insensitive LIKE. `sanitize_sql_like`
          # escapes `_` and `%` so a query like `john_doe@example.com`
          # doesn't have its underscore treated as a wildcard matching
          # `john.doe@example.com`. Pass `\` as the ESCAPE character so
          # SQLite/MySQL honor the escaping.
          escaped = sanitize_query_for_search(query)
          model_class.arel_table[attribute.to_sym].lower.matches("%#{escaped}%", '\\')
        end
      end

      # Backward compatibility aliases — remove in Spree 6.0
      def self.sanitize_query_for_multi_search(query) = sanitize_query_for_search(query)
      def self.multi_search_condition(model_class, attribute, query) = search_condition(model_class, attribute, query)
    end
  end
end
