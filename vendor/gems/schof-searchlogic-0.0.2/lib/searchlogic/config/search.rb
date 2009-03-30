module Searchlogic
  class Config
    # = Search Configuration
    # Provides configuration for searchlogic
    #
    # === Example
    #   Searchlogic::Config.configure do |config|
    #     config.search.per_page = 50
    #   end
    class Search
      class << self
        # The default for per page. This is only applicaple for protected searches. Meaning you start the search with new_search or new_conditions.
        # The reason for this not to disturb regular queries such as Whatever.find(:all). You would not expect that to be limited.
        #
        # * <tt>Default:</tt> The 2nd option in your per_page_choices, default of 25
        # * <tt>Accepts:</tt> Any value in your per_page choices, nil or a blank string means "show all"
        def per_page
          return @per_page if @set_per_page
          per_page = Helpers.per_page_select_choices[1]
          per_page = per_page.last if per_page.is_a?(Array)
          @per_page = per_page
        end
        
        def per_page=(value)
          @set_per_page = true
          @per_page = value
        end
        
        # If you are using ActiveRecord < 2.2.0 then ActiveRecord does not remove duplicates when using the :joins option, when it should. To fix this problem searchlogic does this for you. Searchlogic tries to act
        # just like ActiveRecord, but in this instance it doesn't make sense.
        #
        # As a result, Searchlogic removes all duplicates results in *ALL* search / calculation queries. It does this by forcing the DISTINCT or GROUP BY operation in your SQL. Which might come as a surprise to you
        # since it is not the "norm". If you don't want searchlogic to do this, set this to false.
        #
        # * <tt>Default:</tt> true
        # * <tt>Accepts:</tt> Boolean
        def remove_duplicates
          return @remove_duplicates if @set_remove_duplicates
          @remove_duplicates ||= true
        end

        def remove_duplicates? # :nodoc:
          remove_duplicates == true
        end
        
        def remove_duplicates=(value) # :nodoc:
          @set_remove_duplicates = true
          @remove_duplicates = value
        end
      end
    end
  end
end