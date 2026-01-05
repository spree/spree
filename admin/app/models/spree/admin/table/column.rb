module Spree
  module Admin
    class Table
      class Column
        TYPES = %i[string number date datetime currency status link boolean image custom].freeze
        FILTER_TYPES = %i[string number date datetime currency status boolean autocomplete].freeze

        attr_accessor :key, :label, :type, :filter_type, :sortable, :filterable, :displayable, :default, :position,
                      :partial, :partial_locals, :method, :width, :align, :format, :condition,
                      :ransack_attribute, :operators, :value_options, :search_url,
                      :sort_scope_asc, :sort_scope_desc

        def initialize(key, **options)
          @key = key.to_sym
          @label = options[:label]
          @type = (options[:type] || :string).to_sym
          @filter_type = (options[:filter_type] || @type).to_sym
          @sortable = options.fetch(:sortable, true)
          @filterable = options.fetch(:filterable, true)
          @displayable = options.fetch(:displayable, true)
          @default = options.fetch(:default, false)
          @position = options[:position] || 999
          @partial = options[:partial]
          @partial_locals = options[:partial_locals] || {}
          @method = options[:method] || key
          @width = options[:width]
          @align = options[:align] || :left
          @format = options[:format]
          @condition = options.key?(:if) ? options[:if] : options[:condition]
          @ransack_attribute = options[:ransack_attribute] || key.to_s
          @value_options = options[:value_options]
          @search_url = options[:search_url]
          @operators = options[:operators] || default_operators_for_type
          @sort_scope_asc = options[:sort_scope_asc]
          @sort_scope_desc = options[:sort_scope_desc]
        end

        # Check if column uses custom sort scopes instead of ransack
        # @return [Boolean]
        def custom_sort?
          sort_scope_asc.present? || sort_scope_desc.present?
        end

        def sortable?
          @sortable
        end

        def filterable?
          @filterable
        end

        def displayable?
          @displayable
        end

        def default?
          @default
        end

        # Check if column is visible for the given context
        # @param context [Object, nil] view context with access to helper methods
        # @return [Boolean]
        def visible?(context = nil)
          return true if condition.nil?

          if condition.respond_to?(:call)
            if context&.respond_to?(:instance_exec)
              context.instance_exec(&condition)
            else
              condition.call(context)
            end
          else
            condition
          end
        end

        # Resolve label (handles i18n keys)
        # @return [String]
        def resolve_label
          if label.is_a?(String) && label.present?
            return label
          end

          key_to_translate = label || key
          Spree.t(key_to_translate, default: key_to_translate.to_s.humanize)
        end

        # Resolve value from record
        # @param record [Object] the record to extract value from
        # @param context [Object, nil] view context
        # @return [Object]
        def resolve_value(record, context = nil)
          if method.respond_to?(:call)
            if context&.respond_to?(:instance_exec)
              context.instance_exec(record, &method)
            else
              method.call(record)
            end
          elsif record.respond_to?(method)
            record.send(method)
          end
        end

        # Get default operators based on column filter_type
        # @return [Array<Symbol>]
        def default_operators_for_type
          case filter_type
          when :string
            %i[eq not_eq cont not_cont start end in not_in null not_null]
          when :number, :currency
            %i[eq not_eq gt gteq lt lteq in not_in null not_null]
          when :date, :datetime
            %i[eq not_eq gt gteq lt lteq null not_null]
          when :boolean
            %i[eq]
          when :status
            %i[eq not_eq in not_in]
          when :association, :tags, :autocomplete
            %i[in not_in]
          else
            %i[eq not_eq cont null not_null]
          end
        end

        # Convert to hash
        # @return [Hash]
        def to_h
          {
            key: key,
            label: label,
            type: type,
            filter_type: filter_type,
            sortable: sortable,
            filterable: filterable,
            displayable: displayable,
            default: default,
            position: position,
            partial: partial,
            method: method,
            width: width,
            align: align,
            format: format,
            ransack_attribute: ransack_attribute,
            operators: operators,
            value_options: value_options,
            search_url: search_url,
            sort_scope_asc: sort_scope_asc,
            sort_scope_desc: sort_scope_desc
          }
        end

        # Deep clone the column
        # @return [Column]
        def deep_clone
          self.class.new(key, to_h.merge(condition: condition, method: method))
        end

        def inspect
          "#<Spree::Admin::Table::Column key=#{key} type=#{type} default=#{default}>"
        end
      end
    end
  end
end
