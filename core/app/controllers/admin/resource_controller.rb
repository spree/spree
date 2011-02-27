require 'spree_core/action_callbacks'
require 'spree_core/controller_resource'
class Admin::ResourceController < Admin::BaseController
  helper_method :new_object_url, :edit_object_url, :object_url, :collection_url
  load_and_authorize_resource

  respond_to :html
  
  def new
    render :layout => !request.xhr?
  end
  
  def edit
    render :layout => !request.xhr?
  end
    
  def update
    invoke_callbacks(:update, :before)
    if @object.update_attributes(params[object_name])
      invoke_callbacks(:update, :after)
      resource_desc = I18n.t(object_name)
      resource_desc += " \"#{@object.name}\"" if @object.respond_to?(:name)
      flash[:notice] = I18n.t(:successfully_updated, :resource => resource_desc)
      respond_to do |format|
        format.html { redirect_to location_after_save }
        format.js   { render :layout => false }      
      end
    else
      render :edit
    end
  end

  def create
    invoke_callbacks(:create, :before)
    if @object.save
      invoke_callbacks(:create, :after)
      resource_desc = I18n.t(object_name)
      resource_desc += " \"#{@object.name}\"" if @object.respond_to?(:name)
      flash[:notice] = I18n.t(:successfully_created, :resource => resource_desc)
      respond_to do |format|
        format.html { redirect_to location_after_save }
        format.js   { render :layout => false }      
      end
    else
      render :new
    end
  end
  
  def destroy
    invoke_callbacks(:destroy, :before)
    if @object.destroy
      invoke_callbacks(:destroy, :after)
      resource_desc = I18n.t(object_name)
      resource_desc += " \"#{@object.name}\"" if @object.respond_to?(:name)
      flash[:notice] = I18n.t(:successfully_removed, :resource => resource_desc)
      respond_to do |format|
        format.html { redirect_to collection_url }
        format.js   { render_js_for_destroy }
      end
    else
      redirect_to collection_url
    end
  end
 
  protected
  
  def collection
    model_class.accessible_by(current_ability)
  end
  
  def location_after_save
    collection_url
  end
  
  def self.create
    @@callbacks ||= {}
    @@callbacks["#{controller_name}/create"] ||= Spree::ActionCallbacks.new
  end
  
  def self.update
    @@callbacks ||= {}
    @@callbacks["#{controller_name}/update"] ||= Spree::ActionCallbacks.new
  end
  
  def self.destroy
    @@callbacks ||= {}
    @@callbacks["#{controller_name}/destroy"] ||= Spree::ActionCallbacks.new
  end

  def invoke_callbacks(action, callback_type)
    @@callbacks ||= {}
    return if @@callbacks["#{controller_name}/#{action}"].nil?
    case callback_type.to_sym
      when :before then @@callbacks["#{controller_name}/#{action}"].before_methods.each {|method| send method }
      when :after  then @@callbacks["#{controller_name}/#{action}"].after_methods.each  {|method| send method }
    end
  end

  def render_js_for_destroy
    render :partial => "/admin/shared/destroy"
    flash.notice = nil
  end
  
  def model_class
    controller_name.classify.constantize
  end
  
  def object_name
    controller_name.singularize
  end

  # URL helpers

  def new_object_url(options = {})
    new_polymorphic_url([:admin, model_class], options)
  end
  
  def edit_object_url(object, options = {})
    #edit_polymorphic_url([:admin, object], options)
    send "edit_admin_#{object_name}_url", object, options
  end
  
  def object_url(object = nil, options = {})
    if object
      #polymorphic_url([:admin, object], options)
      send "admin_#{object_name}_url", object, options
    else
      #[:admin, @object]
      send "admin_#{object_name}_url", @object
    end
  end
  
  def collection_url(options = {})
    polymorphic_url([:admin, model_class], options)
  end
end
