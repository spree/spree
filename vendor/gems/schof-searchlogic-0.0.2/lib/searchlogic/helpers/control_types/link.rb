module Searchlogic
  module Helpers
    # = Control Type Helpers
    #
    # The purpose of these helpers is to make ordering and paginating data, in your view, a breeze. Everyone has their own flavor of displaying data, so I made these helpers extra flexible, just for you.
    #
    # === Tutorial
    #
    # Check out my tutorial on how to implement searchlogic into a rails app: http://www.binarylogic.com/2008/9/7/tutorial-pagination-ordering-and-searching-with-searchlogic
    #
    # === How it's organized
    #
    # If we break it down, you can do 4 different things with your data in your view:
    #
    # 1. Order your data by a single column or an array of columns
    # 2. Descend or ascend your data
    # 3. Change how many items are on each page
    # 4. Paginate through your data
    #
    # Each one of these actions comes with 3 different types of helpers:
    #
    # 1. Link - A single link for a single value. Requires that you pass a value as the first parameter.
    # 2. Links - A group of single links.
    # 3. Select - A select with choices that perform an action once selected. Basically the same thing as a group of links, but just as a select form element
    # 4. Remote - lets you prefix any of these helpers with "remote_" and it will use the built in rails ajax helpers. I highly recommend unobstrusive javascript though, using jQuery.
    #
    # === Examples
    #
    # Sometimes the best way to explain something is with some examples. Let's pretend we are performing these actions on a User model. Check it out:
    #
    #   order_by_link(:name)
    #   => produces a single link that when clicked will order by the name column, and each time its clicked alternated between "ASC" and "DESC"
    #
    #   order_by_links
    #   => produces a group of links for all of the columns in your users table, each link is basically order_by_link(column.name)
    #
    #   order_by_select
    #   => produces a select form element with all of the user's columns as choices, when the value is change (onchange) it will act as if they clicked a link.
    #   => This is just order_by_links as a select form element, nothing fancy
    #
    # What about paginating? I got you covered:
    #
    #   page_link(2)
    #   => creates a link to page 2
    #
    #   page_links
    #   => creates a group of links for pages, similar to a flickr style of pagination
    #
    #   page_select
    #   => creates a drop down instead of a group of links. The user can select the page in the drop down and it will be as if they clicked a link for that page.
    #
    # You can apply the _link, _links, or _select to any of the following: order_by, order_as, per_page, page. You have your choice on how you want to set up the interface. For more information and options on these individual
    # helpers check out their source files. Look at the sub modules under this one (Ex: Searchlogic::Helpers::ControlTypes::Select)
    module ControlTypes
      # = Link Control Types
      #
      # These helpers make ordering and paginating your data a breeze in your view. They only produce links.
      module Link
        # Creates a link for ordering data by a column or columns
        #
        # === Example uses for a User class that has many orders
        #
        #   order_by_link(:first_name)
        #   order_by_link([:first_name, :last_name])
        #   order_by_link({:orders => :total})
        #   order_by_link([{:orders => :total}, :first_name])
        #   order_by_link(:id, :text => "Order Number", :html => {:class => "order_number"})
        #
        # What's nifty about this is that the value gets "serialized", if it is not a string or a symbol, so that it can be passed via a param in the url. Searchlogic will automatically try to "unserializes" this value and use it. This allows you
        # to pass complex objects besides strings and symbols, such as arrays and hashes. All of the hard work is done for you.
        #
        # Another thing to keep in mind is that this will alternate between "asc" and "desc" each time it is clicked.
        #
        # === Options
        # * <tt>:text</tt> -- default: column_name.to_s.humanize, text for the link
        # * <tt>:desc_indicator</tt> -- default: &nbsp;&#9660;, the indicator that this column is descending
        # * <tt>:asc_indicator</tt> -- default: &nbsp;&#9650;, the indicator that this column is ascending
        # * <tt>:html</tt> -- html arrtributes for the <a> tag.
        #
        # === Advanced Options
        # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base level in params such as params[:page], params[:per_page], etc, then set this to nil.
        # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
        # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
        # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get included. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
        # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
        # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
        def order_by_link(order_by, options = {})
          add_order_by_link_defaults!(order_by, options)
          html = searchlogic_state(options)
          
          if !options[:is_remote]
            html += link_to(options[:text], options[:url], options[:html])
          else
            html += link_to_remote(options[:text], options[:remote].merge(:url => options[:url]), options[:html])
          end
          
          html
        end
        
        # Creates a link for ascending or descending data.
        #
        # === Example uses
        #
        #   order_as_link("asc")
        #   order_as_link("desc")
        #   order_as_link("asc", :text => "Ascending", :html => {:class => "ascending"})
        #
        # === Options
        # * <tt>:text</tt> -- default: column_name.to_s.humanize, text for the link
        # * <tt>:html</tt> -- html arrtributes for the <a> tag.
        #
        # === Advanced Options
        # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base level in params such as params[:page], params[:per_page], etc, then set this to nil.
        # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
        # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
        # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get included. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
        # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
        # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
        def order_as_link(order_as, options = {})
          add_order_as_link_defaults!(order_as, options)
          html = searchlogic_state(options)
          
          if !options[:is_remote]
            html += link_to(options[:text], options[:url], options[:html])
          else
            html += link_to_remote(options[:text], options[:remote].merge(:url => options[:url]), options[:html])
          end
          
          html
        end
        
        # This is similar to order_by_link but with a small difference. The best way to explain priority ordering is with an example. Let's say you wanted to list products on a page. You have "featured" products
        # that you want to show up first, no matter what. This is what this is all about. It makes ordering by featured products a priority, then searching by price, quantity, etc. is the same as it has always been.
        #
        # The difference between order_by_link and priority_order_by_link is that priority_order_by_link it just a switch. Turn it on or turn it off. You don't neccessarily want to flip between ASC and DESC. If you do
        # then you should just incorporate this into your regular order_by, like: order_by_link [:featured, :price]
        #
        # === Example uses for a User class that has many orders
        #
        #   priority_order_by_link(:featured, "DESC")
        #   order_by_link([:featured, :created_at], "ASC")
        #   order_by_link({:orders => :featured}, "ASC")
        #   order_by_link([{:orders => :featured}, :featured], "ASC")
        #   order_by_link(:featured, "ASC", :text => "Featured", :html => {:class => "featured_link"})
        #
        # === Options
        # * <tt>:activate_text</tt> -- default: "Show #{column_name.to_s.humanize} first"
        # * <tt>:deactivate_text</tt> -- default: "Don't show #{column_name.to_s.humanize} first", text for the link, text for the link
        # * <tt>:column_name</tt> -- default: column_name.to_s.humanize, automatically inferred by what you are ordering by and is added into the active_text and deactive_text strings.
        # * <tt>:text</tt> -- default: :activate_text or :deactivate_text depending on if its active or not, Overwriting this will make this text stay the same, no matter way. A good alternative would be "Toggle featured first"
        # * <tt>:html</tt> -- html arrtributes for the <a> tag.
        #
        # === Advanced Options
        # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base level in params such as params[:page], params[:per_page], etc, then set this to nil.
        # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
        # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
        # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get included. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
        # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
        # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
        def priority_order_by_link(priority_order_by, priority_order_as, options = {})
          add_priority_order_by_link_defaults!(priority_order_by, priority_order_as, options)
          html = searchlogic_state(options)
          
          if !options[:is_remote]
            html += link_to(options[:text], options[:url], options[:html])
          else
            html += link_to_remote(options[:text], options[:remote].merge(:url => options[:url]), options[:html])
          end
          
          html
        end
        
        # Creates a link for limiting how many items are on each page
        #
        # === Example uses
        #
        #   per_page_link(200)
        #   per_page_link(nil) # => Show all
        #   per_page_link(nil, :text => "All", :html => {:class => "show_all"})
        #
        # As you can see above, passing nil means "show all" and the text will automatically revert to "show all"
        #
        # === Options
        # * <tt>:html</tt> -- html arrtributes for the <a> tag.
        #
        # === Advanced Options
        # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base level in params such as params[:page], params[:per_page], etc, then set this to nil.
        # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
        # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
        # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get included. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
        # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
        # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
        def per_page_link(per_page, options = {})
          add_per_page_link_defaults!(per_page, options)
          html = searchlogic_state(options)
          
          if !options[:is_remote]
            html += link_to(options[:text], options[:url], options[:html])
          else
            html += link_to_remote(options[:text], options[:remote].merge(:url => options[:url]), options[:html])
          end
          
          html
        end
        
        # Creates a link for changing to a sepcific page of your data
        #
        # === Example uses
        #
        #   page_link(2)
        #   page_link(1)
        #   page_link(5, :text => "Fifth page", :html => {:class => "fifth_page"})
        #
        # === Options
        # * <tt>:text</tt> -- default: column_name.to_s.humanize, text for the link
        # * <tt>:html</tt> -- html arrtributes for the <a> tag.
        #
        # === Advanced Options
        # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base level in params such as params[:page], params[:per_page], etc, then set this to nil.
        # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
        # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
        # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get included. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
        # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
        # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
        def page_link(page, options = {})
          add_page_link_defaults!(page, options)
          html = searchlogic_state(options)
          
          if !options[:is_remote]
            html += link_to(options[:text], options[:url], options[:html])
          else
            html += link_to_remote(options[:text], options[:remote].merge(:url => options[:url]), options[:html])
          end
          
          html
        end
        
        private
          def add_order_by_link_defaults!(order_by, options = {})
            add_searchlogic_control_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.order_by_link_class_name)
            ordering_by_this = searchlogic_ordering_by?(order_by, options)
            searchlogic_add_class!(options[:html], "ordering") if ordering_by_this
            options[:text] ||= determine_order_by_text(order_by)
            options[:asc_indicator] ||= Config.helpers.order_by_link_asc_indicator
            options[:desc_indicator] ||= Config.helpers.order_by_link_desc_indicator
            options[:text] += options[:search_obj].desc? ? options[:desc_indicator] : options[:asc_indicator] if ordering_by_this
            options[:url] = searchlogic_params(options.merge(:search_params => {:order_by => order_by}))
            options
          end
          
          def add_order_as_link_defaults!(order_as, options = {})
            add_searchlogic_control_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.order_as_link_class_name)
            options[:text] ||= order_as.to_s
            options[:url] = searchlogic_params(options.merge(:search_params => {:order_as => order_as}))
            options
          end
          
          def add_priority_order_by_link_defaults!(priority_order_by, priority_order_as, options = {})
            add_searchlogic_control_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.priority_order_by_link_class_name)
            options[:column_name] ||= determine_order_by_text(priority_order_by).downcase 
            options[:activate_text] ||= Config.helpers.priority_order_by_link_activate_text % options[:column_name]
            options[:deactivate_text] ||= Config.helpers.priority_order_by_link_deactivate_text % options[:column_name]
            active = deep_stringify(options[:search_obj].priority_order_by) == deep_stringify(priority_order_by) && options[:search_obj].priority_order_as == priority_order_as
            options[:text] ||= active ? options[:deactivate_text] : options[:activate_text]
            if active
              options.merge!(:search_params => {:priority_order_by => nil, :priority_order_as => nil})
            else
              options.merge!(:search_params => {:priority_order_by => priority_order_by, :priority_order_as => priority_order_as})
            end
            options[:url] = searchlogic_params(options)
            options
          end
          
          def add_per_page_link_defaults!(per_page, options = {})
            add_searchlogic_control_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.per_page_link_class_name)
            options[:text] ||= per_page.to_s
            options[:url] = searchlogic_params(options.merge(:search_params => {:per_page => per_page}))
            options
          end
          
          def add_page_link_defaults!(page, options = {})
            add_searchlogic_control_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.page_link_class_name)
            options[:text] ||= page.to_s
            options[:url] = searchlogic_params(options.merge(:search_params => {:page => page}))
            options
          end
          
          def determine_order_by_text(column_name, relationship_name = nil)
            case column_name
            when String, Symbol
              relationship_name.blank? ? column_name.to_s.titleize : "#{relationship_name.to_s.titleize} #{column_name.to_s.titleize}"
            when Array
              determine_order_by_text(column_name.first)
            when Hash
              k = column_name.keys.first
              v = column_name.values.first
              determine_order_by_text(v, k)
            end
          end
      end
    end
  end
end

ActionController::Base.helper Searchlogic::Helpers::ControlTypes::Link if defined?(ActionController)