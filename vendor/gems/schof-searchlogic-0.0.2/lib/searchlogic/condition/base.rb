module Searchlogic
  module Condition # :nodoc:
    # = Conditions condition
    #
    # The base class for creating a condition. Your custom conditions should extend this class.
    # See Searchlogic::Conditions::Base.register_condition on how to write your own condition.
    class Base
      include Shared::Utilities
      
      attr_accessor :column, :column_for_type_cast, :column_sql, :column_sql_format, :explicit_any, :klass, :object_name, :table_name
      class_inheritable_accessor :handle_array_value, :ignore_meaningless_value, :join_arrays_with_or, :value_type
      self.ignore_meaningless_value = true
    
      class << self
        # Name of the condition type inferred from the class name
        def condition_type_name
          name.split("::").last.underscore
        end
                
        def handle_array_value?
          handle_array_value == true
        end
        
        def ignore_meaningless_value? # :nodoc:
          ignore_meaningless_value == true
        end
        
        def join_arrays_with_or?
          join_arrays_with_or == true
        end
        
        # Determines what to call the condition for the model
        #
        # Searchlogic tries to create conditions on each model. Before it does this it passes the model to this method to see what to call the condition. If the condition type doesnt want to create a condition on
        # a model it will just return nil and Searchlogic will skip over it.
        def condition_names_for_model
          []
        end
        
        # Same as condition_name_for_model, but for a model's column obj
        def condition_names_for_column
          [condition_type_name]
        end
      end
    
      def initialize(klass, options = {})
        self.klass = klass
        self.table_name = options[:table_name] || klass.table_name
        
        if options[:column]
          self.column = options[:column].class < ::ActiveRecord::ConnectionAdapters::Column ? options[:column] : klass.columns_hash[options[:column].to_s]
          
          if options[:column_for_type_cast]
            self.column_for_type_cast = options[:column_for_type_cast]
          else
            type = (!self.class.value_type.blank? && self.class.value_type.to_s) || (!options[:column_type].blank? && options[:column_type].to_s) || column.sql_type
            self.column_for_type_cast = column.class.new(column.name, column.default.to_s, type, column.null)
          end
          
          self.column_sql_format = options[:column_sql_format] || "{table}.{column}"
        end
      end
      
      def explicit_any? # :nodoc:
        explicit_any == true
      end
      
      # Substitutes string vars with table and column name. Allows us to switch the column and table on the fly and have the condition update appropriately.
      # The table name could be variable depending on the condition. Take STI and more than one child model is used in the condition, the first gets the parent table name, the rest get aliases.
      def column_sql
        column_sql_format.gsub("{table}", quoted_table_name).gsub("{column}", quoted_column_name)
      end
    
      # Allows nils to be meaninful values
      def explicitly_set_value=(value)
        @explicitly_set_value = value
      end
    
      # Need this if someone wants to actually use nil in a meaningful way
      def explicitly_set_value?
        @explicitly_set_value == true
      end
      
      def options
        {:table_name => table_name, :column => column, :column_for_type_cast => column_for_type_cast, :column_sql_format => column_sql_format}
      end
      
      # You should refrain from overwriting this method, it performs various tasks before callign your to_conditions method, allowing you to keep to_conditions simple.
      def sanitize(alt_value = nil) # :nodoc:
        return if value_is_meaningless?
        v = alt_value || value
        if v.is_a?(Array) && !self.class.handle_array_value?
          scope_condition(merge_conditions(*v.collect { |i| sanitize(i) } << {:any => self.class.join_arrays_with_or?}))
        else
          v = v.utc if column && v.respond_to?(:utc) && [:time, :timestamp, :datetime].include?(column.type) && klass.time_zone_aware_attributes && !klass.skip_time_zone_conversion_for_attributes.include?(column.name.to_sym)
          to_conditions(v)
        end
      end
      
      # The value for the condition
      def value
        @casted_value ||= type_cast_value(@value)
      end
    
      # Sets the value for the condition
      def value=(v)
        self.explicitly_set_value = true
        @casted_value = nil
        @value = v
      end
      
      def value_is_meaningless? # :nodoc:
        meaningless?(@value)
      end
      
      private
        def like_condition_name
          @like_condition_name ||= klass.connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"
        end
        
        def meaningless?(v)
          case v
          when Array
            v.each { |i| return false unless meaningless?(i) }
            true
          else
            !explicitly_set_value? || (self.class.ignore_meaningless_value? && v != false && v.blank?)
          end
        end

        def meaningful?(v)
          !meaningless?(v)
        end
        
        def quote_column_name(column_name)
          klass.connection.quote_column_name(column_name)
        end
        
        def quoted_column_name
          quote_column_name(column.name)
        end
        
        def quote_table_name(table_name)
          klass.connection.quote_table_name(table_name)
        end
        
        def quoted_table_name
          quote_table_name(table_name)
        end
        
        def type_cast_value(v)
          case v
          when Array
            v.collect { |i| type_cast_value(i) }.compact
          else
            return if meaningless?(v)
            return v if !column_for_type_cast || !v.is_a?(String)
            tcv = column_for_type_cast.type_cast(v) 
            tcv -= Time.zone.utc_offset if tcv.is_a?(Time)
            tcv
          end
        end
    end
  end
end