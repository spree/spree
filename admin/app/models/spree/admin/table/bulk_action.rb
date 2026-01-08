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
        attribute :modal_path
        attribute :action_path
        attribute :position, :integer, default: 999
        attribute :condition
        attribute :confirm
        attribute :method, default: :put

        # Modal content attributes - used by generic bulk_modal action
        attribute :title
        attribute :title_options, default: -> { {} }
        attribute :body
        attribute :body_options, default: -> { {} }
        attribute :form_partial, :string
        attribute :form_partial_locals, default: -> { {} }

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

        # Resolve title for modal dialog (handles i18n keys)
        # @return [String]
        def resolve_title
          resolve_i18n_attribute(title, title_options, "#{key}.title")
        end

        # Resolve body for modal dialog (handles i18n keys)
        # @return [String]
        def resolve_body
          resolve_i18n_attribute(body, body_options, "#{key}.body")
        end

        # Deep clone the action
        # @return [BulkAction]
        def deep_clone
          self.class.new(**attributes.symbolize_keys.merge(condition: condition))
        end

        def inspect
          "#<Spree::Admin::Table::BulkAction key=#{key}>"
        end

        private

        def resolve_i18n_attribute(value, options, default_key)
          return nil if value.blank?

          if value.is_a?(Symbol)
            Spree.t(value, **options)
          elsif value.is_a?(String) && value.start_with?('admin.')
            Spree.t(value, **options.merge(default: default_key.to_s.humanize))
          elsif value.is_a?(String) && value.present?
            value
          else
            Spree.t(default_key, scope: 'admin.bulk_ops', default: default_key.to_s.humanize, **options)
          end
        end
      end
    end
  end
end
