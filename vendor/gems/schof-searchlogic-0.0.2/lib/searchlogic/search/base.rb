module Searchlogic #:nodoc:
  module Search #:nodoc:
    # = Searchlogic
    #
    # Please refer the README.rdoc for usage, examples, and installation.
    class Base
      include Searchlogic::Shared::Utilities
      include Searchlogic::Shared::VirtualClasses
      
      # Options ActiveRecord allows when searching
      AR_FIND_OPTIONS = ::ActiveRecord::Base.valid_find_options
      
      # Options ActiveRecord allows when performing calculations
      AR_CALCULATIONS_OPTIONS = (::ActiveRecord::Base.valid_calculations_options - [:select, :limit, :offset, :order, :group, :include])
      
      AR_OPTIONS = (AR_FIND_OPTIONS + AR_CALCULATIONS_OPTIONS).uniq
      
      # Options that ActiveRecord doesn't suppport, but Searchlogic does
      SPECIAL_FIND_OPTIONS = [:order_by, :order_as, :page, :per_page, :priority_order, :priority_order_by, :priority_order_as]
      
      # Valid options you can use when searching
      OPTIONS = SPECIAL_FIND_OPTIONS + AR_OPTIONS # the order is very important, these options get set in this order
      
      attr_accessor *AR_OPTIONS
      attr_writer :scope
      
      class << self
        # Used in the ActiveRecord methods to determine if Searchlogic should get involved or not.
        # This keeps Searchlogic out of the way unless it is needed.
        def needed?(model_class, options)
          return false if options.blank?
          
          SPECIAL_FIND_OPTIONS.each do |option|
            return true if options.symbolize_keys.keys.include?(option)
          end
                    
          Searchlogic::Conditions::Base.needed?(model_class, options[:conditions])
        end
      end
      
      def initialize(init_options = {})
        self.options = init_options
      end
      
      # Flag to determine if searchlogic is acting as a filter for the ActiveRecord search methods.
      # By filter it means that searchlogic is being used on the default ActiveRecord search methods, like all, count, find(:all), first, etc.
      def acting_as_filter=(value)
        @acting_as_filter = value
      end
      
      # See acting_as_filter=
      def acting_as_filter?
        @acting_as_filter == true
      end
      
      # Specific implementation of cloning
      def clone
        options = {}
        (AR_OPTIONS - [:conditions]).each { |option| options[option] = instance_variable_get("@#{option}") }
        options[:conditions] = conditions.conditions
        SPECIAL_FIND_OPTIONS.each { |option| options[option] = send(option) }
        obj = self.class.new(options)
        obj.protect = protected?
        obj.scope = scope
        obj
      end
      alias_method :dup, :clone
      
      # Makes using searchlogic in the console less annoying and keeps the output meaningful and useful
      def inspect
        current_find_options = {}
        (AR_OPTIONS - [:conditions]).each do |option|
          value = send(option)
          next if value.nil?
          current_find_options[option] = value
        end
        conditions_value = conditions.conditions
        current_find_options[:conditions] = conditions_value unless conditions_value.blank?
        current_find_options[:scope] = scope unless scope.blank?
        "#<#{klass}Search #{current_find_options.inspect}>"
      end
      
      # Merges all joins together, including the scopes joins for
      def joins
        all_joins = (safe_to_array(conditions.auto_joins) + safe_to_array(order_by_auto_joins) + safe_to_array(priority_order_by_auto_joins) + safe_to_array(@joins)).uniq
        all_joins.size <= 1 ? all_joins.first : all_joins
      end
      
      def limit=(value)
        @set_limit = true
        @limit = value.blank? || value == 0 ? nil : value.to_i
      end
      
      def limit
        @limit ||= Config.search.per_page if !acting_as_filter? && !@set_limit
        @limit
      end
      
      def offset=(value)
        @offset = value.blank? ? nil : value.to_i
      end

      def options=(values)
        return unless values.is_a?(Hash)
        values.symbolize_keys.fast_assert_valid_keys(OPTIONS)
        values.each { |key, value| send("#{key}=", value) }
      end
      
      # Sanitizes everything down into options ActiveRecord::Base.find can understand
      def sanitize(searching = true)  
        find_options = {}
        
        (searching ? AR_FIND_OPTIONS : AR_CALCULATIONS_OPTIONS).each do |find_option|
          value = send(find_option)
          next if value.blank?
          find_options[find_option] = value
        end
        
        find_options
      end
      
      def select
        @select ||= "DISTINCT #{klass.connection.quote_table_name(klass.table_name)}.*" if !joins.blank? && Config.search.remove_duplicates? && klass.connection.adapter_name != "PostgreSQL"
        @select
      end
      
      def scope
        @scope ||= {}
      end
      
      private
        def safe_to_array(o)
          case o
          when NilClass
            []
          when Array
            o
          else
            [o]
          end
        end
        
        def array_of_strings?(o)
          o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
        end
    end
  end
end