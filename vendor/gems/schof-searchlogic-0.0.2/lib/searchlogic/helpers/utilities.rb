module Searchlogic
  module Helpers #:nodoc:
    module Utilities
      # Builds a hash of params for creating a url and preserves any existing params. You can pass this into url_for and build your url. Although most rails helpers accept a hash.
      #
      # Let's take the page_link helper. Here is the code behind that helper:
      #
      #   link_to("Page 2", searchlogic_params(:search_params => {:page => 2}))
      #
      # That's pretty much it. So if you wanted to roll your own link to execute a search, go for it. It's pretty simple. Pass conditions instead of the page, set how the search will be ordered, etc.
      #
      # <b>Be careful</b> when taking this approach though. Searchlogic helps you out when you use form_for. For example, when you use the per_page_select helper, it adds in a hidden form field with the value of the page. So when
      # your search form is submitted it searches the document for that element, finds the current value, which is the current per_page value, and includes that in the search. So when a user searches the per_page
      # value stays consistent. If you use the searchlogic_params you are on your own. I am always curious how people are using searchlogic. So if you are building your own helpers contact me and maybe I can help you
      # and add in a helper for you, making it an *official* feature.
      #
      # === Options
      # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base leve in params such as params[:page], params[:per_page], etc, then set this to nil.
      # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
      # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
      # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get include. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
      # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
      # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
      def searchlogic_params(options = {})
        add_searchlogic_defaults!(options)
        options[:search_params] ||= {}
        options[:literal_search_params] ||= {}
        
        options[:params] ||= {}
        params_copy = params.deep_dup.with_indifferent_access
        search_params = options[:params_scope].blank? ? params_copy : params_copy.delete(options[:params_scope])
        search_params ||= {}
        search_params = search_params.with_indifferent_access
        search_params.delete(:commit)
        search_params.delete(:page)
        search_params.deep_delete_duplicate_keys(options[:literal_search_params])
        search_params.deep_delete(options[:exclude_search_params])
        
        if options[:search_params]
          
          #raise params_copy.inspect if options[:search_params][:order_by] == :id
          search_params.deep_merge!(options[:search_params])
          
          if options[:search_params][:order_by] && !options[:search_params][:order_as]
            search_params[:order_as] = (searchlogic_ordering_by?(options[:search_params][:order_by], options) && options[:search_obj].asc?) ? "DESC" : "ASC" 
          end
          
          [:order_by, :priority_order_by].each { |base64_field| search_params[base64_field] = searchlogic_base64_value(search_params[base64_field]) if search_params.has_key?(base64_field) }
        end
        
        new_params = params_copy
        new_params.deep_merge!(options[:params])
        new_params.deep_delete(options[:exclude_params])
        
        if options[:params_scope].blank? || search_params.blank?
          new_params
        else
          new_params.merge(options[:params_scope] => search_params)
        end
      end
      
      # Similar to searchlogic_hash, but instead returns a string url. The reason this exists is to assist in creating urls in javascript. It's the muscle behind all of the select helpers that searchlogic provides.
      # Take the instance where you want to do:
      #
      #   :onchange => "window.location = '#{url_for(searchlogic_params)}&my_param=' + this.value;"
      #
      # Well the above obviously won't work. Do you need to apped the url with a ? or a &? What about that tricky :params_scope? That's where this is handy, beacuse it does all of the params string building for you. Check it out:
      #
      #   :onchange => "window.location = '" + searchlogic_url(:literal_search_params => {:per_page => "' + escape(this.value) + '"}) + "';"
      #
      # or what about something a little more tricky?
      #
      #   :onchange => "window.location = '" + searchlogic_url(:literal_search_params => {:conditions => {:name_contains => "' + escape(this.value) + '"}}) + "';"
      #
      # I have personally used this for an event calendar. Above the calendar there was a drop down for each month. Here is the code:
      #
      #   :onchange => "window.location = '" + searchlogic_url(:literal_search_params => {:conditions => {:occurs_at_after => "' + escape(this.value) + '"}}) + "';"
      #
      # Now when the user changes the month in the drop down it just runs a new search that sets my conditions to occurs_at_after = selected month. Then in my controller I set occurs_at_before = occurs_at_after.at_end_of_month.
      #
      # === Options
      # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base leve in params such as params[:page], params[:per_page], etc, then set this to nil.
      # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
      # * <tt>:params</tt> -- default: nil, Additional params to add to the url, must be a hash
      # * <tt>:exclude_params</tt> -- default: nil, params you want to exclude. This is nifty because it does a "deep delete". So you can pass {:param1 => {:param2 => :param3}} and it will make sure param3 does not get include. param1 and param2 will not be touched. This also accepts an array or just a symbol or string.
      # * <tt>:search_params</tt> -- default: nil, Additional search params to add to the url, must be a hash. Adds the options into the :params_scope.
      # * <tt>:literal_search_params</tt> -- default: nil, Additional search params to add to the url, but are not escaped. So you can add javascript into the URL: :literal_search_params => {:per_page => "' + escape(this.value) + '"}
      # * <tt>:exclude_search_params</tt> -- default: nil, Same as :exclude_params but for the :search_params.
      def searchlogic_url(options = {})
        search_params = searchlogic_params(options)
        url = url_for(search_params)
        literal_param_strings = literal_param_strings(options[:literal_search_params], options[:params_scope].blank? ? "" : "#{options[:params_scope]}")
        url += (url.last == "?" ? "" : (url.include?("?") ? "&amp;" : "?")) + literal_param_strings.join("&amp;")
      end
      
      # When you set up a search form using form_for for remote_form_for searchlogic adds in some *magic* for you.
      #
      # Take the instance where a user orders the data by something other than the default, and then does a search. The user would expect the search to remember what the user selected to order the data by, right?
      # What searchlogic does is add in some hidden fields, somewhere in the page, the represent the searchlogic "state". These are automatically added for you when you use the searchlogic helpers.
      # Such as: page_links, page_link, order_by_link, per_page_select, etc. So if you are using those you do not need to worry about this helper.
      #
      # If for some reason you do not use any of these you need to put the searchlogic state on your page somewhere. Somewhere where the state will *always* be up-to-date, which would be most likely be in the
      # partial that renders your search results (assuming you are using AJAX). Otherwise when the user starts a new search, the state will be reset. Meaning the order_by, per_page, etc will all be reset.
      #
      # === Options
      # * <tt>:params_scope</tt> -- default: :search, this is the scope in which your search params will be preserved (params[:search]). If you don't want a scope and want your options to be at base leve in params such as params[:page], params[:per_page], etc, then set this to nil.
      # * <tt>:search_obj</tt> -- default: @#{params_scope}, this is your search object, everything revolves around this. It will try to infer the name from your params_scope. If your params_scope is :search it will try to get @search, etc. If it can not be inferred by this, you need to pass the object itself.
      def searchlogic_state(options = {})
        return "" if @added_searchlogic_state
        add_searchlogic_defaults!(options)
        html = ""
        (Search::Base::SPECIAL_FIND_OPTIONS - [:page, :priority_order]).each do |option|
          value = options[:search_obj].send(option)
          html += hidden_field(options[:params_scope], option, :value => (option == :order_by ? searchlogic_base64_value(value) : value))
        end
        @added_searchlogic_state = true
        html
      end
      
      private
        # Adds default options for all helper methods.
        def add_searchlogic_defaults!(options)
          options[:params_scope] = :search unless options.has_key?(:params_scope)
          options[:search_obj] ||= instance_variable_get("@#{options[:params_scope]}")
          raise(ArgumentError, "@search object could not be inferred, please specify: :search_obj => @search or :params_scope => :search_obj_name") unless options[:search_obj].is_a?(Searchlogic::Search::Base)
          options
        end
        
        # Adds default options for all control type helper methods.
        def add_searchlogic_control_defaults!(options)
          add_searchlogic_defaults!(options)
          options[:html] ||= {}
          options
        end
        
        def searchlogic_add_class!(html_options, new_class)
          new_class = new_class.to_s
          html_options[:class] ||= ""
          classes = html_options[:class].split(" ")
          classes << new_class unless classes.include?(new_class)
          html_options[:class] = classes.join(" ")
        end
        
        def searchlogic_base64_value(order_by)
          case order_by
          when String, Symbol
            order_by
          when Array, Hash
            [Marshal.dump(order_by)].pack("m")
          end
        end
        
        def searchlogic_ordering_by?(order_by, options)
          stringified_search_order_by = deep_stringify(options[:search_obj].order_by)
          stringified_order_by = deep_stringify(order_by)
          (options[:search_obj].order_by.blank? && options[:search_obj].klass.primary_key == stringified_order_by) || stringified_search_order_by == stringified_order_by
        end
        
        def literal_param_strings(literal_params, prefix)
          param_strings = []
          
          literal_params.each do |k, v|
            param_string = prefix.blank? ? k.to_s : "#{prefix}[#{k}]"
            case v
            when Hash
              literal_param_strings(v, param_string).each do |literal_param_string|
                param_strings << literal_param_string
              end
            else
              param_strings << (CGI.escape(param_string) + "=#{v}")
            end
          end
          
          param_strings
        end
        
        def deep_stringify(obj)
          case obj
          when String
            obj
          when Symbol
            obj.to_s
          when Array
            obj.collect { |item| deep_stringify(item) }
          when Hash
            new_obj = {}
            obj.each { |key, value| new_obj[key.to_s] = deep_stringify(value) }
            new_obj
          else
            obj
          end
        end
    end
  end
end

ActionController::Base.helper(Searchlogic::Helpers::Utilities) if defined?(ActionController)