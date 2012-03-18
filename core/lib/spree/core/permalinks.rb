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

          validates permalink_options[:field], :uniqueness => true

          if self.table_exists? && self.column_names.include?(permalink_options[:field].to_s)
            before_validation(:on => :create) { save_permalink }
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

        def permalink_order
          order = permalink_options[:order]

          if order
            "#{order} ASC,"
          end
        end

      end

      def save_permalink
        permalink_value = self.to_param
        field = self.class.permalink_field
        order = self.class.permalink_order
        # Do other links exist with this permalink?
        other = self.class.first(
          :conditions => "#{field} LIKE '#{permalink_value}%'",
          :order => "#{order} LENGTH(#{field}) DESC, #{field} DESC"
        )
        if other
          # Find existence of that permalink or the number of that permalink and add one.
          if ( permalink_value == other.send(field) || /-(\d+)$/.match(other.send(field)) )
            if $1
              number = $1.to_i + 1
            # Otherwise default to suffixing it with a 1.
            else
              number = 1
            end

            permalink_value += "-#{number.to_s}"
          end
        end
        write_attribute(field, permalink_value)
      end
    end
  end
end

ActiveRecord::Base.send :include, Spree::Core::Permalinks
ActiveRecord::Relation.send :include, Spree::Core::Permalinks
