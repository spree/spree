module Spree
  module Admin
    class Table
      class BulkAction
        include ActiveModel::Model
        include ActiveModel::Attributes

        METHODS = %i[get post put patch delete].freeze

        attribute :key
        attribute :label
        attribute :label_options, default: -> { {} }
        attribute :icon, :string
        attribute :modal_path, :string
        attribute :action_path, :string
        attribute :position, :integer, default: 999
        attribute :condition
        attribute :confirm, :string
        attribute :method, default: :put

        validates :key, presence: true
        validates :method, presence: true, inclusion: { in: METHODS }

        def initialize(attributes = {})
          # Handle :if as alias for :condition
          attributes[:condition] = attributes.delete(:if) if attributes.key?(:if)
          super
          self.key = key.to_sym if key.is_a?(String)
          self.method = self.method.to_sym if self.method.is_a?(String)
        end

        # Check if action is visible for the given context
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
          if label.is_a?(String) && label.start_with?('admin.')
            # Full translation key
            Spree.t(label, **label_options.merge(default: key.to_s.humanize))
          elsif label.is_a?(String) && label.present?
            label
          else
            key_to_translate = label || key
            Spree.t(key_to_translate, scope: 'admin.bulk_ops', default: key_to_translate.to_s.humanize, **label_options)
          end
        end

        # Deep clone the action
        # @return [BulkAction]
        def deep_clone
          self.class.new(**attributes.symbolize_keys.merge(condition: condition))
        end

        def inspect
          "#<Spree::Admin::Table::BulkAction key=#{key}>"
        end
      end
    end
  end
end
