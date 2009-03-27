module Searchlogic
  # == Searchlogic ActiveRecord
  #
  # Hooks into ActiveRecord to add all of the searchlogic functionality into your models. Only uses what is publically available, doesn't dig into internals, and
  # searchlogic only gets involved when needed.
  module ActiveRecord
    # = Searchlogic ActiveRecord Base
    # Adds in base level functionality to ActiveRecord
    module Base
      # This is an alias method chain. It hook into ActiveRecord's "calculate" method and checks to see if Searchlogic should get involved.
      def calculate_with_searchlogic(*args)
        options = args.extract_options!
        options = filter_options_with_searchlogic(options, false)
        args << options
        calculate_without_searchlogic(*args)
      end
      
      # This is an alias method chain. It hooks into ActiveRecord's "find" method and checks to see if Searchlogic should get involved.
      def find_with_searchlogic(*args)
        options = args.extract_options!
        options = filter_options_with_searchlogic(options)
        args << options
        find_without_searchlogic(*args)
      end
      
      # This is an alias method chain. It hooks into ActiveRecord's scopes and checks to see if Searchlogic should get involved. Allowing you to use all of Searchlogics conditions and tools
      # in scopes as well.
      #
      # === Examples
      #
      # Named scopes:
      #
      #   named_scope :top_expensive, :conditions => {:total_gt => 1_000_000}, :per_page => 10
      #   named_scope :top_expensive_ordered, :conditions => {:total_gt => 1_000_000}, :per_page => 10, :order_by => {:user => :first_name}
      #
      # Good ole' regular scopes:
      #
      #   with_scope(:find => {:conditions => {:total_gt => 1_000_000}, :per_page => 10}) do
      #     find(:all)
      #   end
      #
      #   with_scope(:find => {:conditions => {:total_gt => 1_000_000}, :per_page => 10}) do
      #     build_search
      #   end
      def with_scope_with_searchlogic(method_scoping = {}, action = :merge, &block)
        method_scoping[:find] = filter_options_with_searchlogic(method_scoping[:find]) if method_scoping[:find]
        with_scope_without_searchlogic(method_scoping, action, &block)
      end
      
      # This is a special method that Searchlogic adds in. It returns a new search object on the model. So you can search via an object.
      #
      # <b>This method is "protected". Meaning it checks the passed options for SQL injections. So trying to write raw SQL in *any* of the option will result in a raised exception. It's safe to pass a params object when instantiating.</b>
      #
      # This method has an alias "new_search"
      #
      # === Examples
      #
      #   search = User.new_search
      #   search.conditions.first_name_contains = "Ben"
      #   search.per_page = 20
      #   search.page = 2
      #   search.order_by = {:user_group => :name}
      #   search.all # can call any search method: first, find(:all), find(:first), sum("id"), etc...
      def build_search(options = {}, &block)
        search = searchlogic_search
        search.protect = true
        search.options = options
        yield search if block_given?
        search
      end
      
      # See build_search. This is the same method but *without* protection. Do *NOT* pass in a params object to this method.
      #
      # This also has an alias "new_search!"
      def build_search!(options = {}, &block)
        search = searchlogic_search(options)
        yield search if block_given?
        search
      end
      
      # Similar to ActiveRecord's attr_protected, but for conditions. It will block any conditions in this array that are being mass assigned. Mass assignments are:
      #
      # === Examples
      #
      # search = User.new_search(:conditions => {:first_name_like => "Ben", :email_contains => "binarylogic.com"})
      # search.options = {:conditions => {:first_name_like => "Ben", :email_contains => "binarylogic.com"}}
      #
      # If first_name_like is in the list of conditions_protected then it will be removed from the hash.
      def conditions_protected(*conditions)
        write_inheritable_attribute(:conditions_protected, Set.new(conditions.map(&:to_s)) + (protected_conditions || []))
      end

      def protected_conditions # :nodoc:
        read_inheritable_attribute(:conditions_protected)
      end
      
      # This is the reverse of conditions_protected. You can specify conditions here and *only* these conditions will be allowed in mass assignment. Any condition not specified here will be blocked.
      def conditions_accessible(*conditions)
        write_inheritable_attribute(:conditions_accessible, Set.new(conditions.map(&:to_s)) + (accessible_conditions || []))
      end

      def accessible_conditions # :nodoc:
        read_inheritable_attribute(:conditions_accessible)
      end
    
      private
        def construct_finder_sql_with_included_associations_with_searchlogic(*args)
          sql = construct_finder_sql_with_included_associations_without_searchlogic(*args)
          remove_duplicate_joins(sql)
        end
        
        def construct_finder_sql_with_searchlogic(*args)
          sql = construct_finder_sql_without_searchlogic(*args)
          remove_duplicate_joins(sql)
        end
        
        def construct_calculation_sql_with_searchlogic(*args)
          sql = construct_calculation_sql_without_searchlogic(*args)
          remove_duplicate_joins(sql)
        end
        
        def remove_duplicate_joins(sql)
          join_expr = /(LEFT OUTER JOIN|INNER JOIN)/i
          sql_parts = sql.split(join_expr)
          if !sql_parts.empty?
            last_parts = sql_parts.pop.split(/ (?!ON|AS)([A-Z]+) /)
            sql_parts += last_parts
            is_join_statement = false
            cleaned_parts = []
            sql_parts.each do |part|
              part = part.strip
              if is_join_statement
                if !includes_join?(cleaned_parts, part)
                  cleaned_parts << part
                else
                  cleaned_parts.pop
                end
              else
                cleaned_parts << part
              end
              is_join_statement = part =~ join_expr
            end
            sql = cleaned_parts.join(" ")
          end
          sql
        end
        
        def includes_join?(cleaned_parts, part)
          cleaned_parts.each do |cleaned_part|
            a = cleaned_part.gsub("`", "")
            b = part.gsub("`", "")
            return true if a == b
            return true if a == b.gsub(/([a-z\._]*) = ([a-z\._]*)/, '\2 = \1')
          end
          false
        end
        
        def filter_options_with_searchlogic(options = {}, searching = true)
          return options unless Searchlogic::Search::Base.needed?(self, options)
          search = Searchlogic::Search::Base.create_virtual_class(self).new # call explicitly to avoid merging the scopes into the search
          search.acting_as_filter = true
          search.scope = scope(:find)
          conditions = options.delete(:conditions) || options.delete("conditions") || {}
          if conditions
            case conditions
            when Hash
              conditions.each { |condition, value| search.conditions.send("#{condition}=", value) } # explicitly call to enforce blanks
            else
              search.conditions = conditions
            end
          end
          search.options = options
          search.sanitize(searching)
        end
        
        def searchlogic_search(options = {})
          scope = {}
          current_scope = scope(:find) && scope(:find).deep_dup
          if current_scope
            [:conditions, :include, :joins].each do |option|
              value = current_scope.delete(option)
              next if value.blank?
              scope[option] = value
            end
            
            # Delete nil values in the scope, for some reason habtm relationships like to pass :limit => nil
            new_scope = {}
            current_scope.each { |k, v| new_scope[k] = v unless v.nil? }
            current_scope = new_scope
          end
          search = Searchlogic::Search::Base.create_virtual_class(self).new
          search.scope = scope
          search.options = current_scope
          search.options = options
          search
        end
    end
  end
end

ActiveRecord::Base.send(:extend, Searchlogic::ActiveRecord::Base)

module ActiveRecord #:nodoc: all
  class Base
    class << self
      alias_method_chain :calculate, :searchlogic
      alias_method_chain :construct_finder_sql, :searchlogic
      alias_method_chain :construct_finder_sql_with_included_associations, :searchlogic
      alias_method_chain :construct_calculation_sql, :searchlogic
      alias_method_chain :find, :searchlogic
      alias_method_chain :with_scope, :searchlogic
      alias_method :new_search, :build_search
      alias_method :new_search!, :build_search!
      
      def valid_find_options
        VALID_FIND_OPTIONS
      end
      
      def valid_calculations_options
        Calculations::CALCULATIONS_OPTIONS
      end
    end
  end
end