module Searchlogic
  module Search
    # = Searchlogic Protection
    #
    # This adds protection during mass asignments *only*. This allows you to pass a params object when doing mass assignments and not have to worry about Billy 13 year old adding in SQL injections.
    # There is a section in the readme that covers protection but to reiterate:
    #
    # === Protected
    #
    #   User.new_search(params[:search])
    #   User.new_conditions(params[:search])
    #
    #   search.options = params[:search]
    #   conditions.conditions = params[:conditions]
    #
    # === NOT Protected
    #
    #   User.new_search!(params[:search])
    #   User.new_conditions!(params[:search])
    #   User.find(:all, params[:search])
    #   User.first(params[:search])
    #   User.all(params[:search])
    module Protection
      # Options that are allowed when protecting against SQL injections (still checked though)
      SAFE_OPTIONS = Base::SPECIAL_FIND_OPTIONS + [:conditions, :limit, :offset] - [:priority_order]
      
      VULNERABLE_FIND_OPTIONS = Base::AR_FIND_OPTIONS - SAFE_OPTIONS + [:priority_order]
      
      VULNERABLE_CALCULATIONS_OPTIONS = Base::AR_CALCULATIONS_OPTIONS - SAFE_OPTIONS + [:priority_order]
      
      # Options that are not allowed, at all, when protecting against SQL injections
      VULNERABLE_OPTIONS = Base::OPTIONS - SAFE_OPTIONS
      
      def self.included(klass)
        klass.class_eval do
          attr_reader :protect
          alias_method_chain :options=, :protection
        end
      end
      
      def options_with_protection=(values) # :nodoc:
        return unless values.is_a?(Hash)
        self.protect = values.delete(:protect) if values.has_key?(:protect) # make sure we do this first
        frisk!(values) if protect?
        self.options_without_protection = values
      end
      
      # Accepts a boolean. Will protect mass assignemnts if set to true, and unprotect mass assignments if set to false
      def protect=(value)
        conditions.protect = value
        @protect = value
      end
      
      # Convenience methof for determing if the search is protected or not.
      def protect?
        protect == true
      end
      alias_method :protected?, :protect?
      
      private
        def order_by_safe?(order_by, alt_klass = nil)
          return true if order_by.blank?
          
          k = alt_klass || klass
          column_names = k.column_names
                    
          [order_by].flatten.each do |column|
            case column
            when Hash
              reflection = k.reflect_on_association(column.keys.first.to_sym)
              return false unless reflection
              return false unless order_by_safe?(column.values.first, reflection.klass)
            when Array
              return false unless order_by_safe?(column)
            else
              return false unless column_names.include?(column.to_s)
            end
          end
          
          true
        end
        
        def frisk!(options)
          options.symbolize_keys.fast_assert_valid_keys(SAFE_OPTIONS)
          raise(ArgumentError, ":order_by can only contain colum names and relationships in the string, hash, or array format. You are trying to pass a value that does not meet this criteria.") unless order_by_safe?(get_order_by_value(options[:order_by]))
        end
    end    
  end
end