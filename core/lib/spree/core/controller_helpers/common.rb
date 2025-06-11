module Spree
  module Core
    module ControllerHelpers
      module Common
        extend ActiveSupport::Concern
        included do
          helper_method :title
          helper_method :title=
          helper_method :accurate_title

          layout :get_layout

          protected

          # can be used in views as well as controllers.
          # e.g. <% self.title = 'This is a custom title for this view' %>
          attr_writer :title

          def title
            # Spree::Deprecation.warn(<<-DEPRECATION, caller)
            #   ControllerHelpers::Common is deprecated and will be removed in Spree 5.0.
            # DEPRECATION
            title_string = @title.present? ? @title : accurate_title
            if title_string.present?
              if Spree::Config[:always_put_site_name_in_title] && !title_string.include?(default_title)
                [title_string, default_title].join(" #{Spree::Config[:title_site_name_separator]} ")
              else
                title_string
              end
            else
              default_title
            end
          end

          def default_title
            # Spree::Deprecation.warn(<<-DEPRECATION, caller)
            #   ControllerHelpers::Common is deprecated and will be removed in Spree 5.0.
            # DEPRECATION
            current_store.name
          end

          # this is a hook for subclasses to provide title
          def accurate_title
            # Spree::Deprecation.warn(<<-DEPRECATION, caller)
            #   ControllerHelpers::Common is deprecated and will be removed in Spree 5.0.
            # DEPRECATION
            current_store.seo_title
          end

          private

          def set_user_language
            # Spree::Deprecation.warn(<<-DEPRECATION, caller)
            #   ControllerHelpers::Common#set_user_language is deprecated and will be removed in Spree 5.0.
            #   Please use `before_action :set_locale` instead
            # DEPRECATION

            set_locale
          end

          # Returns which layout to render.
          #
          # You can set the layout you want to render inside your Spree configuration with the +:layout+ option.
          #
          # Default layout is: +app/views/spree/layouts/spree_application+
          #
          def get_layout
            # Spree::Deprecation.warn(<<-DEPRECATION, caller)
            #   ControllerHelpers::Common is deprecated and will be removed in Spree 5.0.
            # DEPRECATION
            return unless defined?(Spree::Frontend)

            layout ||= Spree::Frontend::Config[:layout]
          end
        end
      end
    end
  end
end
