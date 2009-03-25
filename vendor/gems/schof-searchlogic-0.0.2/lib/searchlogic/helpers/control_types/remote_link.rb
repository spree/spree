module Searchlogic
  module Helpers
    module ControlTypes
      # = Remote Link Control Types
      #
      # These helpers use rails built in remote_function as links.
      module RemoteLink
        # The same thing as order_by_link but instead of using rails link_to it uses link_to_remote
        #
        # === Examples
        #
        #   remote_order_by_link
        #   remote_order_by_link(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at order_by_link, this accepts the same options with the following addition:
        #
        # * <tt>:remote</tt> -- default: {}, the options to pass into link_to_remote remote options. Such as :update => {:success => "alert('success')"}
        def remote_order_by_link(order_by, options = {})
          add_remote_defaults!(options)
          order_by_link(order_by, options)
        end
        
        # The same thing as order_as_link but instead of using rails link_to it uses link_to_remote
        #
        # === Examples
        #
        #   remote_order_as_link
        #   remote_order_as_link(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at order_as_link, this accepts the same options with the following addition:
        #
        # * <tt>:remote</tt> -- default: {}, the options to pass into link_to_remote remote options. Such as :update => {:success => "alert('success')"}
        def remote_order_as_link(order_as, options = {})
          add_remote_defaults!(options)
          order_as_link(order_as, options)
        end
        
        # The same thing as per_page_link but instead of using rails link_to it uses link_to_remote
        #
        # === Examples
        #
        #   remote_per_page_link
        #   remote_per_page_link(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at per_page_link, this accepts the same options with the following addition:
        #
        # * <tt>:remote</tt> -- default: {}, the options to pass into link_to_remote remote options. Such as :update => {:success => "alert('success')"}
        def remote_per_page_link(per_page, options = {})
          add_remote_defaults!(options)
          per_page_link(per_page, options)
        end
        
        # The same thing as page_link but instead of using rails link_to it uses link_to_remote
        #
        # === Examples
        #
        #   remote_page_link
        #   remote_page_link(:remote => {:update => "users"})
        #
        # === Options
        #
        # Please look at page_link, this accepts the same options with the following addition:
        #
        # * <tt>:remote</tt> -- default: {}, the options to pass into link_to_remote remote options. Such as :update => {:success => "alert('success')"}
        def remote_page_link(page, options = {})
          add_remote_defaults!(options)
          page_link(page, options)
        end
        
        private
          def add_remote_defaults!(options)
            options[:remote] ||= {}
            options[:remote][:method] ||= :get
            options[:is_remote] = true
          end
      end
    end
  end
end

ActionController::Base.helper Searchlogic::Helpers::ControlTypes::RemoteLink if defined?(ActionController)