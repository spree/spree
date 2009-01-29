class Admin::CssPointsController < ApplicationController
  resource_controller
  require_role :admin

  def edit_via_ajax
    _render_css_listing(CssPoint.find(params[:id]).theme_id)
  end

  def cancel_edit
    _render_css_listing(CssPoint.find(params[:id]).theme_id)
  end

  def save_via_ajax
    theme_id = _save_css_point(CssPoint.find(params[:css_point][:id]))
    _render_css_listing(theme_id)
  end

  def create_via_ajax
    theme_id = _save_css_point(CssPoint.new)
    _render_css_listing(theme_id)
  end

  destroy.after do
    @theme_id = object.theme_id
  end

  destroy.response do |wants|
    wants.html do
      _render_css_listing(@theme_id.to_s)
    end
  end
  
  private
  def _save_css_point(css_point)
    css_point.theme_id = params[:css_point][:theme_id]
    css_point.key = params[:css_point][:key]
    css_point.value = params[:css_point][:value]
    css_point.save
    css_point.theme_id
  end

  def _render_css_listing(theme_id)
    @css_points = CssPoint.find_all_by_theme_id(theme_id) #or empty
    render :partial => '/admin/themes/css_points', :locals => {:css_points => @css_points, :theme_id => theme_id}
  end
end
