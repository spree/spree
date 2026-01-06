module Spree
  module Admin
    class Table
      class Column
        include ActiveModel::Model
        include ActiveModel::Attributes

        TYPES = %w[string number date datetime currency status link boolean image custom association].freeze
        FILTER_TYPES = %w[string number date datetime currency status boolean autocomplete select].freeze

        attribute :key, :string
        attribute :label
        attribute :type, :string, default: 'string'
        attribute :filter_type, :string
        attribute :sortable, :boolean, default: true
        attribute :filterable, :boolean, default: true
        attribute :displayable, :boolean, default: true
        attribute :default, :boolean, default: false
        attribute :position, :integer, default: 999
        attribute :partial, :string
        attribute :partial_locals, default: -> { {} }
        attribute :method
        attribute :width, :string
        attribute :align, :string, default: 'left'
        attribute :format, :string
        attribute :condition
        attribute :ransack_attribute, :string
        attribute :operators, default: -> { [] }
        attribute :value_options
        attribute :search_url, :string
        attribute :sort_scope_asc
        attribute :sort_scope_desc

        alias_method :sortable?, :sortable
        alias_method :filterable?, :filterable
        alias_method :displayable?, :displayable
        alias_method :default?, :default

        validates :key, presence: true
        validates :label, presence: true
        validates :type, presence: true, inclusion: { in: TYPES }
        validates :filter_type, inclusion: { in: FILTER_TYPES }, allow_blank: true

        def initialize(attributes = {})
          super
          set_defaults
        end

        # Check if column uses custom sort scopes instead of ransack
        def custom_sort?
          sort_scope_asc.present? || sort_scope_desc.present?
        end

        # Check if column is visible for the given context
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
        def resolve_label
          if label.is_a?(String) && label.present?
            if label.include?('.')
              return I18n.t(label, default: label.split('.').last.humanize)
            end
            return label
          end

          key_to_translate = label || key
          Spree.t(key_to_translate, default: key_to_translate.to_s.humanize)
        end

        # Resolve value from record
        def resolve_value(record, context = nil)
          if self.method.respond_to?(:call)
            if context&.respond_to?(:instance_exec)
              context.instance_exec(record, &self.method)
            else
              self.method.call(record)
            end
          elsif record.respond_to?(self.method)
            record.send(self.method)
          end
        end

        # Deep clone the column
        def deep_clone
          self.class.new(**attributes.symbolize_keys)
        end

        def inspect
          "#<Spree::Admin::Table::Column key=#{key} type=#{type} default=#{self.default}>"
        end

        private

        def set_defaults
          self.method ||= key
          self.ransack_attribute ||= key.to_s
          self.filter_type ||= FILTER_TYPES.include?(type) ? type : nil
          self.operators = default_operators_for_type if operators.empty?
        end

        def default_operators_for_type
          case filter_type
          when 'string'
            %i[eq not_eq cont not_cont start end in not_in null not_null]
          when 'number', 'currency'
            %i[eq not_eq gt gteq lt lteq in not_in null not_null]
          when 'date', 'datetime'
            %i[eq not_eq gt gteq lt lteq null not_null]
          when 'boolean'
            %i[eq]
          when 'status', 'select'
            %i[eq not_eq in not_in]
          when 'association', 'tags', 'autocomplete'
            %i[in not_in]
          else
            %i[eq not_eq cont null not_null]
          end
        end
      end
    end
  end
end
