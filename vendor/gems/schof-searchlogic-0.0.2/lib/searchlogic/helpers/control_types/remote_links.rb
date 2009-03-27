module Searchlogic
  module Helpers
    module ControlTypes
      # = Remote Links Control Types
      #
      # These helpers use rails built in remote_function as links. They are the same thing as the Links control type, but just use rails built in remote helpers.
      module RemoteLinks
        # Same as order_by_links, but uses link_to_remote instead of remote.
        #
        # === Examples
        #
        #   remote_order_by_links
        #   remote_order_by_links(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at remote_order_by_link and order_by_links. All options there are applicable here. This is just a wrapper method for those 2 methods.
        def remote_order_by_links(options = {})
          add_remote_defaults!(options)
          order_by_links(options)
        end
        
        # Same as order_as_links, but uses link_to_remote instead of remote.
        #
        # === Examples
        #
        #   remote_order_as_links
        #   remote_order_as_links(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at remote_order_as_link and order_as_links. All options there are applicable here. This is just a wrapper method for those 2 methods.
        def remote_order_as_links(options = {})
          add_remote_defaults!(options)
          order_as_link(options)
        end
        
        # Same as per_page_links, but uses link_to_remote instead of remote.
        #
        # === Examples
        #
        #   remote_per_page_links
        #   remote_per_page_links(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at remote_per_page_link and per_page_links. All options there are applicable here. This is just a wrapper method for those 2 methods.
        def remote_per_page_links(options = {})
          add_remote_defaults!(options)
          per_page_links(options)
        end
        
        # Same as page_links, but uses link_to_remote instead of remote.
        #
        # === Examples
        #
        #   remote_page_links
        #   remote_page_links(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at remote_page_link and page_links. All options there are applicable here. This is just a wrapper method for those 2 methods.
        def remote_page_links(options = {})
          add_remote_defaults!(options)
          page_links(options)
        end
      end
    end
  end
end

ActionController::Base.helper Searchlogic::Helpers::ControlTypes::RemoteLinks if defined?(ActionController)