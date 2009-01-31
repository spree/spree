class Admin::ThemesController < ApplicationController
  resource_controller
  layout 'admin'
  require_role :admin
  before_filter :load_css, :only => [:edit, :update]

  update.response do |wants|
    wants.html { redirect_to edit_object_url }
  end

  create.response do |wants|
    wants.html { redirect_to edit_object_url }
  end

  def generate
    @css_points = CssPoint.find_all_by_theme_id(params[:id])
    File.open("#{SPREE_ROOT}/public/stylesheets/css_themes_stylesheet.css", "w") do |log|
      for css_point in @css_points
        log.puts(css_point.key+' { '+css_point.value+" }\n")
      end
    end
    flash[:notice] = Theme.find(params[:id]).name+" has been applied"
    redirect_to collection_url
  end

  private
  def load_css
    @css_points = CssPoint.find_all_by_theme_id(params[:id])
  end
end
