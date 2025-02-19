module Spree
  module ThemeConcern
    extend ActiveSupport::Concern

    included do
      helper 'spree/theme'
      include Spree::ThemeHelper
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
  end
end
