module Spree
  module Admin
    class Table
      class BulkAction
        attr_accessor :key, :label, :label_options, :icon, :modal_path, :action_path, :position, :condition, :confirm, :method

        def initialize(key, **options)
          @key = key.to_sym
          @label = options[:label]
          @label_options = options[:label_options] || {}
          @icon = options[:icon]
          @modal_path = options[:modal_path]
          @action_path = options[:action_path]
          @position = options[:position] || 999
          @condition = options.key?(:if) ? options[:if] : options[:condition]
          @confirm = options[:confirm]
          @method = options[:method] || :put
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

        # Convert to hash
        # @return [Hash]
        def to_h
          {
            key: key,
            label: label,
            label_options: label_options,
            icon: icon,
            modal_path: modal_path,
            action_path: action_path,
            position: position,
            confirm: confirm,
            method: method
          }
        end

        # Deep clone the action
        # @return [BulkAction]
        def deep_clone
          self.class.new(key, to_h.merge(condition: condition))
        end

        def inspect
          "#<Spree::Admin::Table::BulkAction key=#{key}>"
        end
      end
    end
  end
end
