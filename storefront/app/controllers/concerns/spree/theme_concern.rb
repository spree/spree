module Spree
  module ThemeConcern
    extend ActiveSupport::Concern

    included do
      helper 'spree/theme'
      include Spree::ThemeHelper

      prepend_before_action :set_theme_view_paths
    end

    def default_url_options
      if current_theme.present? && current_theme_preview.present?
        super.merge!(theme_id: current_theme.id, theme_preview_id: current_theme_preview.id)
      elsif params[:theme_id].present? && params[:theme_preview_id].blank?
        super.merge!(theme_id: params[:theme_id])
      else
        super
      end
    end

    def set_theme_view_paths
      # add default Spree theme
      prepend_view_path [Spree::Storefront::Engine.root, 'app/views/themes/default'].join('/')
      # add current theme
      prepend_view_path "app/views/themes/#{current_theme.class.name.demodulize.underscore}"
    end
  end
end
