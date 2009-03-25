module Searchlogic
  module Search
    # = Searchlogic Pagination
    #
    # Adds in pagination functionality to searchlogic
    module Pagination
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :limit=, :pagination
          alias_method_chain :offset=, :pagination
          alias_method :per_page, :limit
          alias_method :per_page=, :limit=
        end
      end
      
      def limit_with_pagination=(value) # :nodoc:
        r_value = self.limit_without_pagination = value
        @page_count = nil
        if @set_page
          self.page = (@queued_page || @page) # retry setting page
        else
          @page = nil # the memoized page is invalid, so reset it
        end
        r_value
      end
      
      def offset_with_pagination=(value) #:nodoc
        r_value = self.offset_without_pagination = value
        @set_page = @queued_page = @page = nil
        r_value
      end
      
      # The current page that the search is on
      def page
        @page ||= (offset.blank? || limit.blank?) ? 1 : (offset.to_f / limit).floor + 1
      end
      alias_method :current_page, :page
      
      # Lets you change the page for the next search
      def page=(value)
        @set_page = true
        
        if value.blank?
          value = nil
          @page = value
          return @offset = @page
        end
        
        v = value.to_i
        
        if limit.blank?
          @queued_page = v
          @page = 1
          @offset = nil
        else
          @queued_page = nil
          @page = v
          v -= 1 unless v == 0
          @offset = v * limit
        end
        value
      end
      
      # The total number of pages in your next search
      def page_count
        @page_count ||= (per_page.blank? || per_page <= 0) ? 1 : (count / per_page.to_f).ceil
      end
      alias_method :page_total, :page_count
      
      # Always returns 1, this is a convenience method
      def first_page
        1
      end
      
      # Changes the page to 1 and then runs the "all" search. What's different about this method is that it does not raise an exception if you are on the first page. Unlike prev_page! and next_page!
      # I don't think an exception raised is warranted, because you are expecting the same results each time it is ran.
      def first_page!
        self.page = first_page
        all
      end
      
      # Changes the page to the page - 1
      def prev_page
        self.page - 1
      end
      
      # Changes the page to page - 1 and runs the "all" search. Be careful with this method because if you are on the first page an exception is raised telling you that you are on the first page.
      # I thought about just running the first page search again, but that seems confusing and unexpected.
      def prev_page!
        raise("You are on the first page") if page == first_page
        self.page = prev_page
        all
      end
      
      # Change the page to page + 1
      def next_page
        self.page + 1
      end
      
      # Changes the page to page + 1 and calls the "all" method. Be careful with this method because if you are on the last page an exception is raised telling you that you are on the last page.
      # I thought about just running the lat page search again, but that seems confusing and unexpected.
      def next_page!
        raise("You are on the last page") if page == last_page
        self.page = next_page
        all
      end
      
      # Always returns the page_count, this is a convenience method
      def last_page
        page_count
      end
      
      # Changes the page to the last page and runs the "all" search. What's different about this method is that it does not raise an exception if you are on the last page. Unlike prev_page! and next_page!
      # I don't think an exception raised is warranted, because you are expecting the same results each time it is ran.
      def last_page!
        self.page = last_page
        all
      end
    end
  end
end