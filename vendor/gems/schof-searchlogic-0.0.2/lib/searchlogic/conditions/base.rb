module Searchlogic
  module Conditions # :nodoc:
    # = Conditions
    #
    # Represents a collection of conditions and performs various tasks on that collection. For information on each condition see Searchlogic::Condition.
    # Each condition has its own file and class and the source for each condition is pretty self explanatory.
    class Base
      include Shared::Utilities
      include Shared::VirtualClasses
      
      attr_accessor :object_name
      
      class << self
        # Registers a condition as an available condition for a column or a class. MySQL supports a "sounds like" function. I want to use it, so let's add it.
        #
        # === Example
        #
        #   # config/initializers/searchlogic.rb
        #   # Actual function for MySQL databases only
        #   class SoundsLike < Searchlogic::Condition::Base
        #     # The name of the conditions. By default its the name of the class, if you want alternate or alias conditions just add them on.
        #     # If you don't want to add aliases you don't even need to define this method
        #     def self.condition_names_for_column
        #       super + ["similar_to", "sounds"]
        #     end
        #
        #     # You can return an array or a string. NOT a hash, because all of these conditions
        #     # need to eventually get merged together. The array or string can be anything you would put in
        #     # the :conditions option for ActiveRecord::Base.find(). Also notice the column_sql variable. This is essentail
        #     # for applying modifiers and should be used in your conditions wherever you want the column.
        #     def to_conditions(value)
        #       ["#{column_sql} SOUNDS LIKE ?", value]
        #     end
        #   end
        #
        #   Searchlogic::Conditions::Base.register_condition(SoundsLike)
        def register_condition(condition_class)
          raise(ArgumentError, "You can only register conditions that extend Searchlogic::Condition::Base") unless condition_class.ancestors.include?(Searchlogic::Condition::Base)
          conditions << condition_class unless conditions.include?(condition_class)
        end
        
        # A list of available condition type classes
        def conditions
          @@conditions ||= []
        end
        
        # Registers a modifier as an available modifier for each column.
        #
        # === Example
        #
        #   # config/initializers/searchlogic.rb
        #   class Ceil < Searchlogic::Modifiers::Base
        #     # The name of the modifier. By default its the name of the class, if you want alternate or alias modifiers just add them on.
        #     # If you don't want to add aliases you don't even need to define this method
        #     def self.modifier_names
        #       super + ["round_up"]
        #     end
        #
        #     # The name of the method in the connection adapters (see below). By default its the name of your class suffixed with "_sql".
        #     # So in this example it would be "ceil_sql". Unless you want to change that you don't need to define this method.
        #     def self.adapter_method_name
        #       super
        #     end
        #
        #     # This is the type of value returned from the modifier. This is neccessary for typcasting values for the modifier when
        #     # applied to a column
        #     def self.return_type
        #       :integer
        #     end
        #   end
        #
        #   Searchlogic::Seearch::Conditions.register_modifiers(Ceil)
        #
        # Now here's the fun part, applying this modifier to each connection adapter. Some databases call modifiers differently. If they all apply them the same you can
        # add in the function to ActiveRecord::ConnectionAdapters::AbstractAdapter, otherwise you need to add them to each
        # individually: ActiveRecord::ConnectionAdapters::MysqlAdapter, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, ActiveRecord::ConnectionAdapters::SQLiteAdapter
        #
        # Do this by includine a model with your method. The name of your method, by default, is: #{modifier_name}_sql. So in the example above it would be "ceil_sql"
        #
        #   module CeilAdapterMethod
        #     def ceil_sql(column_name)
        #       "CEIL(#{column_name})"
        #     end
        #   end
        #
        #   ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, CeilAdapterMethod)
        #   # ... include for the rest of the adapters
        def register_modifier(modifier_class)
          raise(ArgumentError, "You can only register conditions that extend Searchlogic::Modifiers::Base") unless modifier_class.ancestors.include?(Searchlogic::Modifiers::Base)
          modifiers << modifier_class unless modifiers.include?(modifier_class)
        end
        
        # A list of available modifier classes
        def modifiers
          @@modifiers ||= []
        end
        
        def needed?(model_class, conditions) # :nodoc:
          return false if conditions.blank?
          
          if conditions.is_a?(Hash)
            return true if conditions[:any]
            stringified_conditions = conditions.stringify_keys
            stringified_conditions.keys.each { |condition| return false if condition.include?(".") } # setting conditions on associations, which is just another way of writing SQL, and we ignore SQL
            
            column_names = model_class.column_names
            stringified_conditions.keys.each do |condition|
              return true unless column_names.include?(condition)
            end
          end
          
          false
        end
      end
      
      # Initializes a conditions object, accepts a hash of conditions as the single parameter
      def initialize(init_conditions = {})
        self.conditions = init_conditions
      end
      
      # A list of joins to use when searching, includes relationships
      def auto_joins
        j = []
        association_objects.each do |association|
          next if association.conditions.blank?
          association_joins = association.auto_joins
          j << (association_joins.blank? ? association.object_name : {association.object_name => association_joins})
        end
        j.blank? ? nil : (j.size == 1 ? j.first : j)
      end
      
      # Provides a much more informative and easier to understand inspection of the object
      def inspect
        "#<#{klass}Conditions#{conditions.blank? ? "" : " #{conditions.inspect}"}>"
      end
      
      # Sanitizes the conditions down into conditions that ActiveRecord::Base.find can understand.
      def sanitize
        return @conditions if @conditions # return the conditions if the user set them with a string, aka sql conditions
        joined_conditions = nil
        objects.each do |object|
          sanitized_conditions = group?(object) ? scope_condition(object.sanitize) : object.sanitize
          joined_conditions = merge_conditions(joined_conditions, sanitized_conditions, :any => join_object_with_any?(object))
        end
        joined_conditions
      end
      
      # Allows you to set the conditions via a hash.
      def conditions=(value)
        case value
        when Array
          value.each { |v| self.conditions = v }
        when Hash
          remove_conditions_from_protected_assignement(value).each do |condition, condition_value|
            next if [:conditions].include?(condition.to_sym) # protect sensitive methods
            
            # delete all blanks from mass assignments, forms submit blanks, blanks are meaningless
            # equals condition thinks everything is meaningful, and arrays can be pased
            new_condition_value = nil
            case condition_value
            when Array
              new_condition_value = condition_value.reject { |v| v == "" }
              next if new_condition_value.empty?
              new_condition_value = new_condition_value.first if new_condition_value.size == 1
            else
              next if condition_value == ""
              new_condition_value = condition_value
            end
            
            send("#{condition}=", new_condition_value)
          end
        else
          reset!
          @conditions = value
        end
      end
      
      # All of the active conditions (conditions that have been set)
      def conditions
        return @conditions if @conditions
        
        conditions_hash = {}
        
        association_objects.each do |association_object|
          relationship_conditions = association_object.conditions
          next if relationship_conditions.blank?
          conditions_hash[association_object.object_name] = relationship_conditions
        end
        
        condition_objects.each do |condition_object|
          next if condition_object.value_is_meaningless?
          conditions_hash[condition_object.object_name] = condition_object.value
        end
        
        conditions_hash
      end
      
      # Resets all of the conditions, including conditions set on associations
      def reset!
        objects.each { |object| eval("@#{object.object_name} = nil") }
        objects.clear
      end
      
      private
        def association_objects
          objects.select { |object| association?(object) }
        end
        
        def association?(object)
          object.class < Base && object.class != self.class
        end
        
        def condition_objects
          objects.select { |object| condition?(object) }
        end
        
        def condition?(object)
          object.class < Condition::Base
        end
        
        def objects
          @objects ||= []
        end
        
        def join_object_with_any?(object)
          return any? if !any.nil?
          if condition?(object) || group?(object)
            object.explicit_any?
          elsif association?(object)
            object.send(:join_object_with_any?, object.send(:objects).first)
          end
        end
        
        def remove_conditions_from_protected_assignement(conditions)
          return conditions if klass.accessible_conditions.nil? && klass.protected_conditions.nil?
          if klass.accessible_conditions
            conditions.reject { |condition, value| !klass.accessible_conditions.include?(condition.to_s) }
          elsif klass.protected_conditions
            conditions.reject { |condition, value| klass.protected_conditions.include?(condition.to_s) }
          end
        end
    end
  end
end