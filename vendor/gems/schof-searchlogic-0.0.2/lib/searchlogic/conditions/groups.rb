module Searchlogic
  module Conditions
    # = Groups
    #
    # Allows you to group conditions, similar to how you would group conditions with parenthesis in an SQL statement. See the "Group conditions" section in the READM for examples.
    module Groups
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :auto_joins, :groups
        end
      end
      
      def auto_joins_with_groups
        auto_joins = auto_joins_without_groups
        auto_joins = auto_joins.is_a?(Array) ? auto_joins : [auto_joins].compact
        
        group_objects.each do |group|
          next if group.conditions.blank?
          group_joins = group.auto_joins
          next if group_joins.blank?
          group_joins = group_joins.is_a?(Array) ? group_joins : [group_joins]
          auto_joins += group_joins
        end
        
        auto_joins.blank? ? nil : (auto_joins.size == 1 ? auto_joins.first : auto_joins)
      end
      
      # Creates a new group object to set condition off of. See examples at top of class on how to use this.
      def group(conditions = nil, &block)
        obj = self.class.new
        obj.conditions = conditions unless conditions.nil?
        yield obj if block_given?
        objects << obj
        obj
      end
      alias_method :group=, :group
      
      def and_group(*args, &block)
        obj = group(*args, &block)
        obj.explicit_any = false
        obj
      end
      alias_method :and_group=, :and_group
      
      def or_group(*args, &block)
        obj = group(*args, &block)
        obj.explicit_any = true
        obj
      end
      alias_method :or_group=, :or_group
      
      def explicit_any=(value) # :nodoc:
        @explicit_any = value
      end
      
      def explicit_any # :nodoc
        @explicit_any
      end
      
      def explicit_any? # :nodoc:
        ["true", "1", "yes"].include? explicit_any.to_s
      end
      
      private
        def group_objects
          objects.select { |object| group?(object) }
        end
        
        def group?(object)
          object.class == self.class
        end
    end
  end
end