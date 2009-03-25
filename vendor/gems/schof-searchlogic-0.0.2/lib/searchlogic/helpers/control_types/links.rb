module Searchlogic
  module Helpers
    module ControlTypes
      module Links
        # Creates a group of links that order the data by a column or columns. All that this does is loop through the :choices option and call order_by_link and then glue it all together.
        #
        # === Examples
        #
        #   order_by_links
        #   order_by_links(:choices => [:name, {:orders => {:line_items => :total}}, :email])
        #
        # === Options
        #
        # Please look at order_by_link. All options there are applicable here and are passed onto each option.
        #
        # * <tt>:choices</tt> -- default: the models column names, the choices to loop through when calling order_by_link
        def order_by_links(options = {})
          add_order_by_links_defaults!(options)
          links_options = options.deep_dup
          links_options.delete(:choices)
          html = ""
          options[:choices].each do |choice|
            link_options = links_option.deep_dup
            text, value = option_text_and_value(choice)
            link_options[:text] ||= text
            html += order_by_link(value, link_options)
          end
          html
        end
        
        # Creates a group of links that ascend or descend the data. All that this does is loop through the :choices option and call order_as_link and then glue it all together.
        #
        # === Examples
        #
        #   order_as_links
        #   order_as_links(:choices => [:ascending, :descending])
        #
        # === Options
        #
        # Please look at order_as_link. All options there are applicable here and are passed onto each option.
        #
        # * <tt>:choices</tt> -- default: ["asc", "desc"], the choices to loop through when calling order_as_link
        def order_as_links(options = {})
          add_order_as_links_defaults!(options)
          links_options = options.deep_dup
          links_options.delete(:choices)
          html = ""
          options[:choices].each do |choice|
            link_options = links_option.deep_dup
            text, value = option_text_and_value(choice)
            link_options[:text] ||= text
            html += order_as_link(value, link_options)
          end
          html
        end
        
        # Creates a group of links that limit how many items are on each page. All that this does is loop through the :choices option and call per_page_link and then glue it all together.
        #
        # === Examples
        #
        #   per_page_links
        #   per_page_links(:choices => [25, 50, nil])
        #
        # === Options
        #
        # Please look at per_page_link. All options there are applicable here and are passed onto each option.
        #
        # * <tt>:choices</tt> -- default: [["10 per page", 10], ["25 per page", 25], ["50 per page", 50], ["100 per page", 100], ["150 per page", 150], ["200 per page", 200], ["Show all", nil]]
        def per_page_links(options = {})
          add_per_page_links_defaults!(options)
          links_options = options.deep_dup
          links_options.delete(:choices)
          html = ""
          options[:choices].each do |choice|
            link_options = links_options.deep_dup
            text, value = option_text_and_value(choice)
            link_options[:text] ||= text
            searchlogic_add_class!(link_options[:html], Config.helpers.order_by_links_ordering_by_class_name) if link_options[:search_obj].per_page == value
            html += per_page_link(value, link_options)
          end
          html
        end
        
        # Creates a group of links that paginate through the data. Kind of like a flickr page navigation. This one has some nifty options.
        #
        # === Examples
        #
        #   page_links
        #   page_links(:first => "<< First", :last => "Last >>")
        #
        # === Classes and tags
        #
        # If the user is on the current page they will get a <span> tag, not an <a> tag. If they are on the first page the "first" and "prev" options will be a <span> also. The same goes
        # for "next" and "last" if the user is on the last page. Other than that each element will come with a CSS class so you can style it to your liking. Somtimes the easiest way to understand this
        # Is to either look at the example (linked in the README) or try it out and view the HTML source. It's pretty simple, but here are the explanations:
        #
        # * <tt>page</tt> - This is in *every* element, span or a.
        # * <tt>first_page</tt> - This is for the "first page" element only.
        # * <tt>prev_page</tt> - This is for the "prev page" element only.
        # * <tt>current_page</tt> - This is for the current page element
        # * <tt>next_page</tt> - This is for the "next page" element only.
        # * <tt>last_page</tt> - This is for the "last page" element only.
        # * <tt>disabled_page</tt> - Any element that is a span instead of an a tag.
        #
        # === Options
        #
        # Please look at per_page_link. All options there are applicable here and are passed onto each option.
        #
        # * <tt>:inner_spread</tt> -- default: 3, set to nil to show all pages, set 0 to show no page links. This represents how many choices available on each side of the current page
        # * <tt>:outer_spread</tt> -- default: 1, set to nil to disable, set to 0 show no outer spread but the separator will still be present. This represents how many choices are in the "outer" spread.
        # * <tt>:prev</tt> -- default: "< Prev", set to nil to omit. This is an extra link on the left side of the page links that will go to the previous page
        # * <tt>:next</tt> -- default: "Next >", set to nil to omit. This is an extra link on the right side of the page links that will go to the next page
        # * <tt>:first</tt> -- default: nil, set to nil to omit. This is an extra link on thefar left side of the page links that will go to the first page
        # * <tt>:last</tt> -- default: nil, set to nil to omit. This is an extra link on the far right side of the page links that will go to the last page
        def page_links(options = {})
          add_page_links_defaults!(options)
          return if options[:last_page] <= 1
          
          inner_spread_start = inner_spread_end = lower_gap = lower_outer_spread_start = lower_outer_spread_end = upper_gap = upper_outer_spread_start = upper_outer_spread_end = 0
          if !options[:inner_spread].blank?
            inner_spread_start = options[:current_page] - options[:inner_spread]
            inner_spread_start = options[:first_page] if inner_spread_start < options[:first_page]
            inner_spread_end = options[:current_page] + options[:inner_spread]
            inner_spread_end = options[:last_page] if inner_spread_end > options[:last_page]
            
            if !options[:outer_spread].blank?
              lower_gap = inner_spread_start - options[:first_page]
              if lower_gap > 0
                lower_outer_spread_start = options[:first_page]
                lower_outer_spread_end = options[:outer_spread] > lower_gap ? lower_gap : options[:outer_spread]
              end
              
              upper_gap = options[:last_page] - inner_spread_end
              if upper_gap > 0
                upper_outer_spread_start = options[:last_page] - (options[:outer_spread] > upper_gap ? upper_gap : options[:outer_spread]) + 1
                upper_outer_spread_end = options[:last_page]
              end
            end
          else
            inner_spread_start = options[:first_page]
            inner_spread_end = options[:last_page]
          end
          
          html = ""
          html += span_or_page_link(:first, options.deep_dup, options[:current_page] == options[:first_page]) if options[:first]
          html += span_or_page_link(:prev, options.deep_dup, options[:current_page] == options[:first_page]) if options[:prev]
          
          if lower_gap > 0
            (lower_outer_spread_start..lower_outer_spread_end).each { |page| html += span_or_page_link(page, options.deep_dup, false) }
            html += content_tag(:span, "&hellip;", options[:html]) if (inner_spread_start - lower_outer_spread_end) > 1
          end
          
          (inner_spread_start..inner_spread_end).each { |page| html += span_or_page_link(page, options.deep_dup, page == options[:current_page]) }
          
          if upper_gap > 0
            html += content_tag(:span, "&hellip;", options[:html]) if (upper_outer_spread_start - inner_spread_end) > 1
            (upper_outer_spread_start..upper_outer_spread_end).each { |page| html += span_or_page_link(page, options.deep_dup, false) }
          end
          
          html += span_or_page_link(:next, options.deep_dup, options[:current_page] == options[:last_page]) if options[:next]
          html += span_or_page_link(:last, options.deep_dup, options[:current_page] == options[:last_page]) if options[:last]
          html = content_tag(:div, html, :class => Config.helpers.page_links_div_wrapper_class_name) if Config.helpers.page_links_div_wrapper
          html
        end
        
        private
          def add_order_by_links_defaults!(options)
            add_searchlogic_control_defaults!(options)
            options[:choices] ||= options[:search_obj].klass.column_names.map(&:humanize)
            options
          end
          
          def add_order_as_links_defaults!(options)
            add_searchlogic_control_defaults!(options)
            options[:choices] = [:asc, :desc]
            options
          end
          
          def add_per_page_links_defaults!(options)
            add_searchlogic_control_defaults!(options)
            options[:choices] ||= Config.helpers.per_page_links_choices.dup
            if !options[:search_obj].per_page.blank? && !choices_include?(options[:choices], options[:search_obj].per_page)
              options[:choices] << ["#{options[:search_obj].per_page} per page", options[:search_obj].per_page]
              options[:choices].sort! do |a, b|
                a_value = (a.is_a?(Array) ? a.last : a).to_i
                return -1 if a_value == 0
                b_value = (b.is_a?(Array) ? b.last : b).to_i
                a_value <=> b_value
              end
            end
            options
          end
          
          def choices_include?(choices, includes)
            choices.each do |choice|
              value = choice.is_a?(Array) ? choice.last : choice
              return true if value == includes
            end
            false
          end
          
          def add_page_links_defaults!(options)
            add_searchlogic_control_defaults!(options)
            options[:first_page] ||= 1
            options[:last_page] ||= options[:search_obj].page_count
            options[:current_page] ||= options[:search_obj].page
            options[:inner_spread] = Config.helpers.page_links_inner_spread unless options.has_key?(:inner_spread)
            options[:outer_spread] = Config.helpers.page_links_outer_spread unless options.has_key?(:outer_spread)
            options[:prev] = Config.helpers.page_links_prev unless options.has_key?(:prev)
            options[:next] = Config.helpers.page_links_next unless options.has_key?(:next)
            options[:first] = Config.helpers.page_links_first unless options.has_key?(:first)
            options[:last] = Config.helpers.page_links_last unless options.has_key?(:last)
            options
          end
          
          def span_or_page_link(name, options, span)
            text = ""
            page = 0
            case name
            when Fixnum
              text = name
              page = name
              searchlogic_add_class!(options[:html], Config.helpers.page_links_current_page_class_name) if span
            else
              text = options[name]
              page = options[:search_obj].send("#{name}_page")
              searchlogic_add_class!(options[:html], Config.helpers.send("page_links_#{name}_page_class_name"))
            end
            
            if span
              searchlogic_add_class!(options[:html], Config.helpers.page_links_disabled_class_name)
              searchlogic_add_class!(options[:html], Config.helpers.page_link_class_name)
            end
            options[:text] = text
            span ? content_tag(:span, text, options[:html]) : page_link(page, options)
          end
      end
    end
  end
end

ActionController::Base.helper Searchlogic::Helpers::ControlTypes::Links if defined?(ActionController)