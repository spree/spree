require 'stringex'

module Spree
  module Core
    module Permalinks
      extend ActiveSupport::Concern

      included do
        class_attribute :permalink_options
      end

      module ClassMethods
        def make_permalink(options={})
          options[:field] ||= :permalink
          self.permalink_options = options

          if self.connected?
            if self.table_exists? && self.column_names.include?(permalink_options[:field].to_s)
              before_validation(:on => :create) { save_permalink }
            end
          end
        end

        def find_by_param(value, *args)
          self.send("find_by_#{permalink_field}", value, *args)
        end

        def find_by_param!(value, *args)
          self.send("find_by_#{permalink_field}!", value, *args)
        end

        def permalink_field
          permalink_options[:field]
        end

        def permalink_prefix
          permalink_options[:prefix] || ""
        end

        def permalink_order
          order = permalink_options[:order]
          "#{order} ASC," if order
        end
      end

      def generate_permalink
        "#{self.class.permalink_prefix}#{Array.new(9){rand(9)}.join}"
      end

      def save_permalink(permalink_value=self.to_param)
        self.with_lock do
          permalink_value ||= generate_permalink

          field = self.class.permalink_field
            # Do other links exist with this permalink?
            other = self.class.where("#{self.class.table_name}.#{field} LIKE ?", "#{permalink_value}%")
            if other.any?
              # Find the existing permalink with the highest number, and increment that number.
              # (If none of the existing permalinks have a number, this will evaluate to 1.)
              number = other.map { |o| o.send(field)[/-(\d+)$/, 1].to_i }.max + 1
              permalink_value += "-#{number.to_s}"
            end
          write_attribute(field, permalink_value)
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Spree::Core::Permalinks
ActiveRecord::Relation.send :include, Spree::Core::Permalinks
