# frozen_string_literal: true

module Spree
  # Resolves `cf_*` custom-field predicates (e.g. +cf_custom_material_i_cont+)
  # into scopes. Ransack has no such attributes, so callers split them out of a
  # filter hash with {with_custom_field_filters} before handing the rest to
  # Ransack. Lives on the model rather than in a SearchProvider so every
  # consumer — the search providers, CSV export, any other Ransack entry
  # point — resolves the same vocabulary.
  module CustomFieldFilterable
    extend ActiveSupport::Concern

    # Arel comparison methods for numeric predicates.
    NUMERIC_OPERATORS = {
      'eq' => :eq,
      'gt' => :gt,
      'gteq' => :gteq,
      'lt' => :lt,
      'lteq' => :lteq
    }.freeze

    # Wraps a value in the LIKE pattern its predicate implies.
    LIKE_PATTERNS = {
      'cont' => ->(value) { "%#{value}%" },
      'i_cont' => ->(value) { "%#{value}%" },
      'start' => ->(value) { "#{value}%" },
      'end' => ->(value) { "%#{value}" }
    }.freeze

    class_methods do
      # Applies every `cf_*` predicate in +filters+ and returns the resulting
      # scope alongside the filters Ransack should still handle. Predicates
      # that don't apply (unknown key, wrong type, unparseable value) are
      # dropped rather than raising, so a stale bookmarked filter degrades to
      # "no filter" instead of a 500.
      #
      # @param filters [Hash]
      # @param schema [Spree::SearchProvider::CustomFieldSchema, nil]
      # @return [Array(ActiveRecord::Relation, Hash)] scoped relation + remaining filters
      def with_custom_field_filters(filters, schema: nil)
        return [all, filters] if filters.blank?
        # Skip the schema's DB query entirely for the common case of a filter
        # hash with no custom-field predicates at all.
        return [all, filters] unless filters.any? { |key, _| key.to_s.start_with?('cf_') }

        schema ||= Spree::SearchProvider::CustomFieldSchema.new
        scope = all

        remaining = filters.reject do |key, value|
          parsed = schema.parse_filter(key)
          next false unless parsed

          condition = custom_field_filter_condition(parsed[:definition], parsed[:predicate], value)
          scope = scope.where(condition) if condition
          true
        end

        [scope, remaining]
      end

      # One EXISTS / NOT EXISTS subquery per predicate — composes with other
      # filters without duplicating rows the way a join would.
      #
      # @param definition [Spree::CustomFieldDefinition]
      # @param predicate [String]
      # @param value [Object]
      # @return [Arel::Nodes::Node, nil] nil when the value is unusable
      def custom_field_filter_condition(definition, predicate, value)
        case predicate
        when 'present'
          custom_field_exists(definition)
        when 'blank'
          custom_field_exists(definition).not
        else
          value_condition = custom_field_value_condition(definition.field_type, predicate, value)
          value_condition && custom_field_exists(definition, value_condition)
        end
      end

      # Type-casts a custom_field value column so numeric fields compare
      # numerically rather than lexicographically. Public because custom_field
      # sorting in Spree::SearchProvider::Database applies the same cast to a
      # differently-aliased join.
      #
      # @param column [Arel::Attributes::Attribute] value column
      # @param field_type [String]
      # @return [Arel::Nodes::Node] castable expression
      def custom_field_value_expression(column, field_type)
        return column unless field_type == 'number'

        Arel::Nodes::NamedFunction.new('CAST', [column.as(custom_field_numeric_cast_type)])
      end

      private

      # `CAST(... AS <type>)` target for numeric custom_field comparisons. SQLite
      # has no DECIMAL affinity and PostgreSQL rejects MySQL's precision form,
      # so the type is per-adapter.
      def custom_field_numeric_cast_type
        case connection.adapter_name
        when /PostgreSQL/i then 'numeric'
        when /Mysql|Trilogy/i then 'DECIMAL(30, 10)'
        else 'REAL'
        end
      end

      # `EXISTS (SELECT 1 FROM spree_custom_fields WHERE …)` correlated against
      # this model's rows, optionally narrowed by a value condition.
      def custom_field_exists(definition, value_condition = nil)
        custom_fields = custom_field_filter_table
        subquery = Arel::SelectManager.new(custom_fields).
                   project(Arel.sql('1')).
                   where(custom_fields[:resource_type].eq(name)).
                   where(custom_fields[:resource_id].eq(arel_table[primary_key])).
                   where(custom_fields[:custom_field_definition_id].eq(definition.id))

        subquery = subquery.where(value_condition) if value_condition

        # `.ast`, not the SelectManager — Exists adds its own parentheses, and
        # a manager contributes a second set, yielding invalid `EXISTS ((…))`.
        Arel::Nodes::Exists.new(subquery.ast)
      end

      # Aliased so the correlated subquery can't collide with an outer join on
      # the same table (custom_field sorting joins it as `sort_cf`).
      def custom_field_filter_table
        @custom_field_filter_table ||= Spree::CustomField.arel_table.alias('filter_cf')
      end

      def custom_field_value_condition(field_type, predicate, value)
        column = custom_field_filter_table[:value]

        if field_type == 'number'
          operator = NUMERIC_OPERATORS[predicate]
          return nil unless operator

          numeric = begin
            BigDecimal(value.to_s)
          rescue ArgumentError, TypeError
            return nil
          end

          custom_field_value_expression(column, field_type).public_send(operator, numeric)
        elsif (pattern = LIKE_PATTERNS[predicate])
          escaped = sanitize_sql_like(value.to_s)
          # LIKE is already case-insensitive under MySQL's default collation
          # and for ASCII on SQLite, but not on PostgreSQL — lower both sides
          # so `i_cont` behaves the same everywhere.
          if predicate == 'i_cont'
            column.lower.matches(pattern.call(escaped.downcase), nil, true)
          else
            column.matches(pattern.call(escaped), nil, true)
          end
        elsif predicate == 'eq'
          column.eq(value.to_s)
        elsif predicate == 'not_eq'
          column.not_eq(value.to_s)
        end
      end
    end
  end
end
