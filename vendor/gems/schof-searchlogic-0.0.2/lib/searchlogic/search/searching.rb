module Searchlogic
  module Search
    # = Searchlogic Searching
    #
    # Implements searching functionality for searchlogic. Searchlogic::Search::Base and Searchlogic::Conditions::Base can both search and include
    # this module.
    module Searching
      # Use these methods just like you would in ActiveRecord
      SEARCH_METHODS = [:all, :find, :first]
      CALCULATION_METHODS = [:average, :calculate, :count, :maximum, :minimum, :sum]
      
      (SEARCH_METHODS + CALCULATION_METHODS).each do |method|
        class_eval <<-"end_eval", __FILE__, __LINE__
          def #{method}(*args)
            find_options = {}
            options = args.extract_options! # can't pass options, your options are in the search
            klass.send(:with_scope, :find => acting_as_filter? ? {} : scope) do
              options = sanitize(#{SEARCH_METHODS.include?(method)})
              if #{CALCULATION_METHODS.include?(method)}
                options[:distinct] = true if #{method == :count} && !joins.blank? && Config.search.remove_duplicates?
                args[0] = klass.column_names.first if [nil, :all].include?(args[0])
              end
              args << options
              results = klass.#{method}(*args)
              results
            end
          end
        end_eval
      end
    end
  end
end