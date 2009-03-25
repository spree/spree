module Searchlogic
  class Config
    # = Helpers Configuration
    # Provide configuration for searchlogic's rails helpers
    #
    # === Example
    #   Searchlogic::Config.configure do |config|
    #     config.helpers.order_by_link_asc_indicator = "ASC"
    #   end
    class Helpers
      class << self
        # Which hidden fields to automatically include when creating a form with a Searchlogic object. See Searchlogic::Helpers::Form for more info.
        #
        # * <tt>Default:</tt> [:order_by, :order_as, :priority_order_by, :priority_order_as, :per_page]
        # * <tt>Accepts:</tt> Array, nil, false
        def hidden_fields
          @hidden_fields ||= (Searchlogic::Search::Base::SPECIAL_FIND_OPTIONS - [:page, :priority_order])
        end
        attr_writer :hidden_fields
        
        # Searchlogic does some javascript magic when you use the form helpers with a Searchlogic object. To make configuration easier Searchlogic checks for the existence of Prototype and jQuery and uses the first
        # one it finds. To cut back on the javascript output you can specify your library here.
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> :prototype or :jquery
        def javascript_library
          @javascript_library
        end
        attr_writer :javascript_library
      
        # The class name for used in the order_as_link helper
        #
        # * <tt>Default:</tt> "order_as"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def order_as_link_class_name
          return @order_as_link_class_name if defined?(@order_as_link_class_name)
          @order_as_link_class_name = "order_as"
        end
        attr_writer :order_as_link_class_name
        
        # The class name for used in the order_as_select helper
        #
        # * <tt>Default:</tt> "order_as"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def order_as_select_class_name
          return @order_as_select_class_name if defined?(@order_as_select_class_name)
          @order_as_select_class_name = "order_as"
        end
        attr_writer :order_as_select_class_name
        
        # The indicator that is used when the sort of a column is ascending
        #
        # * <tt>Default:</tt> &nbsp;&#9650;
        # * <tt>Accepts:</tt> String or a Proc.
        #
        # === Examples
        #
        #   config.asc_indicator = "(ASC)"
        #   config.asc_indicator = Proc.new { |template| template.image_tag("asc.jpg") }
        def order_by_link_asc_indicator
          @order_by_link_asc_indicator ||= "&nbsp;&#9650;"
        end
        attr_writer :order_by_link_asc_indicator
      
        # The class name for used in the order_by_link helper
        #
        # * <tt>Default:</tt> "order_by"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def order_by_link_class_name
          return @order_by_link_class_name if defined?(@order_by_link_class_name)
          @order_by_link_class_name = "order_by"
        end
        attr_writer :order_by_link_class_name
      
        # See order_by_link_asc_indicator=
        def order_by_link_desc_indicator
          @order_by_link_desc_indicator ||= "&nbsp;&#9660;"
        end
        attr_writer :order_by_link_desc_indicator
        
        # The class name used in order_by_links for the link that it is currently ordering by
        #
        # * <tt>Default:</tt> "# The class name for used in the page_link helper
        #
        # * <tt>Default:</tt> "page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def order_by_links_ordering_by_class_name
          return @order_by_links_ordering_by_class_name if defined?(@order_by_links_ordering_by_class_name)
          @order_by_links_ordering_by_class_name = "ordering_by"
        end
        attr_writer :order_by_links_ordering_by_class_name
        
        # The class name for used in the order_by_select helper
        #
        # * <tt>Default:</tt> "order_by"
        # * <tt>Accepts:</tt> String
        def order_by_select_class_name
          @order_by_select_class_name ||= "order_by"
        end
        attr_writer :order_by_select_class_name
        
        # Makes page_links look just like the output of will_paginate.
        #
        # * <tt>Default:</tt> false
        # * <tt>Accepts:</tt> Boolean
        def page_links_act_like_will_paginate
          @page_links_act_like_will_paginate ||= false
        end
        attr_writer :page_links_act_like_will_paginate
        
        # Convenience methods for determining if page_links_act_like_will_paginate is set to true
        def page_links_act_like_will_paginate?
          page_links_act_like_will_paginate == true
        end
        
        # The class name for used in the page_link helper
        #
        # * <tt>Default:</tt> "page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_link_class_name
          return @page_link_class_name if defined?(@page_link_class_name)
          @page_link_class_name = "page"
        end
        attr_writer :page_link_class_name
        
        # The choices used in the per_page_links helper. Works just like per_page_select_choices.
        def per_page_links_choices
          @per_page_links_choices ||= per_page_select_choices
        end
        attr_writer :per_page_links_choices
        
        # The class that the current page link gets.
        #
        # * <tt>Default:</tt> "current_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_current_page_class_name
          return @page_links_current_page_class_name if defined?(@page_links_current_page_class_name)
          @page_links_current_page_class_name = page_links_act_like_will_paginate? ? "current" : "current_page"
        end
        attr_writer :page_links_current_page_class_name
        
        # The class that disabled page links get. Including the current page, prev page, next page, first page, and last page.
        #
        # * <tt>Default:</tt> "disabled_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_disabled_class_name
          return @page_links_disabled_class_name if defined?(@page_links_disabled_class_name)
          @page_links_disabled_class_name = page_links_act_like_will_paginate? ? "disabled" : "disabled_page"
        end
        attr_writer :page_links_disabled_class_name
        
        # Wraps page links in a div
        #
        # * <tt>Default:</tt> false
        # * <tt>Accepts:</tt> Boolean
        def page_links_div_wrapper
          return @page_links_div_wrapper if defined?(@page_links_div_wrapper)
          @page_links_div_wrapper = page_links_act_like_will_paginate?
        end
        attr_writer :page_links_div_wrapper
        
        # If page_links_div_wrapper is true you can specify a class name here.
        #
        # * <tt>Default:</tt> "pagination"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_div_wrapper_class_name
          return @page_links_div_wrapper_class_name if defined?(@page_links_div_wrapper_class_name)
          @page_links_div_wrapper_class_name = "pagination"
        end
        attr_writer :page_links_div_wrapper_class_name
        
        # The default for the :first option for the page_links helper.
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> Anything you want, text, html, etc. nil to disable
        def page_links_first
          @page_links_first
        end
        attr_writer :page_links_first
        
        # The default for the :inner_spread option for the page_links helper.
        #
        # * <tt>Default:</tt> 3
        # * <tt>Accepts:</tt> Any integer >= 1, set to nil to show all pages
        def page_links_inner_spread
          @page_links_inner_spread ||= 3
        end
        attr_writer :page_links_inner_spread
        
        # The class for the first page link
        #
        # * <tt>Default:</tt> "first_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_first_page_class_name
          return @page_links_first_page_class_name if defined?(@page_links_first_page_class_name)
          @page_links_first_page_class_name = "first_page"
        end
        attr_writer :page_links_first_page_class_name
        
        # The default for the :last option for the page_links helper.
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> Anything you want, text, html, etc. nil to disable
        def page_links_last
          @page_links_last
        end
        attr_writer :page_links_last
        
        # The class for the last page link
        #
        # * <tt>Default:</tt> "last_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_last_page_class_name
          return @page_links_last_page_class_name if defined?(@page_links_last_page_class_name)
          @page_links_last_page_class_name = "last_page"
        end
        attr_writer :page_links_last_page_class_name
        
        # The default for the :next option for the page_links helper.
        #
        # * <tt>Default:</tt> "Next >"
        # * <tt>Accepts:</tt> Anything you want, text, html, etc. nil to disable
        def page_links_next
          @page_links_next ||= "Next &gt;"
        end
        attr_writer :page_links_next
        
        # The class for the next page link
        #
        # * <tt>Default:</tt> "next_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_next_page_class_name
          return @page_links_next_page_class_name if defined?(@page_links_next_page_class_name)
          @page_links_next_page_class_name = "next_page"
        end
        attr_writer :page_links_next_page_class_name
        
        # The default for the :outer_spread option for the page_links helper.
        #
        # * <tt>Default:</tt> 2
        # * <tt>Accepts:</tt> Any integer >= 1, set to nil to display, 0 to only show the "..." separator
        def page_links_outer_spread
          @page_links_outer_spread ||= 1
        end
        attr_writer :page_links_outer_spread
        
        # The class for the previous page link
        #
        # * <tt>Default:</tt> "prev_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_links_prev_page_class_name
          return @page_links_prev_page_class_name if defined?(@page_links_prev_page_class_name)
          @page_links_prev_page_class_name = "prev_page"
        end
        attr_writer :page_links_prev_page_class_name
        
        # The default for the :prev option for the page_links helper.
        #
        # * <tt>Default:</tt> "< Prev"
        # * <tt>Accepts:</tt> Anything you want, text, html, etc. nil to disable
        def page_links_prev
          @page_links_prev ||= "&lt; Prev"
        end
        attr_writer :page_links_prev
        
        # The class name for used in the page_seect helper
        #
        # * <tt>Default:</tt> "page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def page_select_class_name
          return @page_select_class_name if defined?(@page_select_class_name)
          @page_select_class_name = "page"
        end
        attr_writer :page_select_class_name
        
        # The class name for used in the per_page_link helper
        #
        # * <tt>Default:</tt> "per_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def per_page_link_class_name
          return @per_page_link_class_name if defined?(@per_page_link_class_name)
          @per_page_link_class_name = "per_page"
        end
        attr_writer :per_page_link_class_name
        
        # The choices used in the per_page_select helper
        #
        # * <tt>Default:</tt> [["10 per page", 10], ["25 per page", 25], ["50 per page", 50], ["100 per page", 100], ["150 per page", 150], ["200 per page", 200], ["Show all", nil]]
        # * <tt>Accepts:</tt> Array
        def per_page_select_choices
          return @per_page_select_choices if @per_page_select_choices
          @per_page_select_choices = []
          [10, 25, 50, 100, 150, 200].each { |choice| @per_page_select_choices << ["#{choice} per page", choice] }
          @per_page_select_choices << ["Show all", nil]
        end
        attr_writer :per_page_select_choices
        
        # The class name for used in the per_page_select helper
        #
        # * <tt>Default:</tt> "per_page"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def per_page_select_class_name
          return @per_page_select_class_name if defined?(@per_page_select_class_name)
          @per_page_select_class_name = "per_page"
        end
        attr_writer :per_page_select_class_name
        
        # The default value for the :activate_text option for priority_order_by_link
        #
        # * <tt>Default:</tt> "Show %s first"
        # * <tt>Accepts:</tt> String with substitutions, using rubys % method for strings
        def priority_order_by_link_activate_text
          @priority_order_by_link_activate_text ||= "Show %s first"
        end
        attr_writer :priority_order_by_link_activate_text
      
        # The class name for used in the priority_order_by_link helper
        #
        # * <tt>Default:</tt> "priority_order_by"
        # * <tt>Accepts:</tt> String, set to nil to disable
        def priority_order_by_link_class_name
          return @priority_order_by_link_class_name if defined?(@priority_order_by_link_class_name)
          @priority_order_by_link_class_name = "priority_order_by"
        end
        attr_writer :priority_order_by_link_class_name
      
        # The default value for the :deactivate_text option for priority_order_by_link
        #
        # * <tt>Default:</tt> "Dont' show %s first"
        # * <tt>Accepts:</tt> String with substitutions, using rubys % method for strings
        def priority_order_by_link_deactivate_text
          @priority_order_by_link_deactivate_text ||= "Don't show %s first"
        end
        attr_writer :priority_order_by_link_deactivate_text
      end
    end
  end
end