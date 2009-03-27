module Searchlogic
  module Helpers
    module ControlTypes
      # = Select Control Types
      #
      # These create <select> tags to help navigate through search data. This is here as an alternative to the Links control types.
      module Select
        # Please see order_by_links. All options are the same and applicable here. The only difference is that instead of a group of links, this gets returned as a select form element that will perform the same function when the value is changed.
        def order_by_select(options = {})
          add_order_by_select_defaults!(options)
          searchlogic_state(options) + select(options[:params_scope], :order_by, options[:choices], options[:tag], options[:html] || {})
        end
        
        # Please see order_as_links. All options are the same and applicable here. The only difference is that instead of a group of links, this gets returned as a select form element that will perform the same function when the value is changed.
        def order_as_select(options = {})
          add_order_as_select_defaults!(options)
          searchlogic_state(options) + select(options[:params_scope], :order_as, options[:choices], options[:tag], options[:html])
        end
        
        # Please see per_page_links. All options are the same and applicable here. The only difference is that instead of a group of links, this gets returned as a select form element that will perform the same function when the value is changed.
        def per_page_select(options = {})
          add_per_page_select_defaults!(options)
          searchlogic_state(options) + select(options[:params_scope], :per_page, options[:choices], options[:tag], options[:html])
        end
        
        # Please see page_links. All options are the same and applicable here, excep the :prev, :next, :first, and :last options. The only difference is that instead of a group of links, this gets returned as a select form element that will perform the same function when the value is changed.
        def page_select(options = {})
          add_page_select_defaults!(options)
          searchlogic_state(options) + select(options[:params_scope], :page, (options[:first_page]..options[:last_page]), options[:tag], options[:html])
        end
        
        private
          def add_order_by_select_defaults!(options)
            add_order_by_links_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.order_by_select_class_name)
            add_searchlogic_select_defaults!(:order_by, options)
            options
          end
          
          def add_order_as_select_defaults!(options)
            add_order_as_links_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.order_as_select_class_name)
            add_searchlogic_select_defaults!(:order_as, options)
            options
          end
          
          def add_per_page_select_defaults!(options)
            add_per_page_links_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.per_page_select_class_name)
            add_searchlogic_select_defaults!(:per_page, options)
            options
          end
          
          def add_page_select_defaults!(options)
            add_page_links_defaults!(options)
            searchlogic_add_class!(options[:html], Config.helpers.page_select_class_name)
            add_searchlogic_select_defaults!(:page, options)
            options
          end
          
          def add_searchlogic_select_defaults!(option, options)
            options[:tag] ||= {}
            options[:tag][:object] = options[:search_obj]
            
            url = searchlogic_url(options.merge(:literal_search_params => {option => "'+this.value+'"}))
            
            options[:html][:onchange] ||= ""
            options[:html][:onchange] += ";"
            if !options[:remote]
              options[:html][:onchange] += "window.location='#{url}';"
            else
              options[:html][:onchange] += remote_function(:url => url, :method => :get).gsub(/\\'\+this.value\+\\'/, "'+this.value+'")
            end
            options[:html][:id] ||= "#{option}_select"
            options
          end
      end
    end
  end
end

ActionController::Base.helper Searchlogic::Helpers::ControlTypes::Select if defined?(ActionController)