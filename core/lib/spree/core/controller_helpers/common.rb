module Spree
  module Core
    module ControllerHelpers
      module Common
        def self.included(base)
          base.class_eval do
            helper_method :title
            helper_method :title=
            helper_method :accurate_title
            helper_method :current_order

            layout :get_layout
          end
        end

        protected

        # can be used in views as well as controllers.
        # e.g. <% title = 'This is a custom title for this view' %>
        attr_writer :title

        def title
          title_string = @title.present? ? @title : accurate_title
          if title_string.present?
            if Spree::Config[:always_put_site_name_in_title]
              [default_title, title_string].join(' - ')
            else
              title_string
            end
          else
            default_title
          end
        end

        def default_title
          Spree::Config[:site_name]
        end

        # this is a hook for subclasses to provide title
        def accurate_title
          Spree::Config[:default_seo_title]
        end

        def render_404(exception = nil)
          respond_to do |type|
            type.html { render :status => :not_found, :file    => "#{::Rails.root}/public/404", :formats => [:html], :layout => nil}
            type.all  { render :status => :not_found, :nothing => true }
          end
        end
        private

        def set_user_language
          locale = session[:locale]
          locale ||= Spree::Config[:default_locale] unless Spree::Config[:default_locale].blank?
          locale ||= Rails.application.config.i18n.default_locale
          locale ||= I18n.default_locale unless I18n.available_locales.include?(locale.to_sym)
          I18n.locale = locale.to_sym
        end

        # Returns which layout to render.
        # 
        # You can set the layout you want to render inside your Spree configuration with the +:layout+ option.
        # 
        # Default layout is: +app/views/spree/layouts/spree_application+
        # 
        def get_layout
          layout ||= Spree::Config[:layout]
        end
      end
    end
  end
end
