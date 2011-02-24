require 'spree_core/action_callbacks'
class Admin::ResourceController < Admin::BaseController
  helper_method :new_object_url, :edit_object_url, :object_url, :collection_url
  load_and_authorize_resource
  respond_to :html
    
  def update
    invoke_callbacks(:update, :before)
    if object.update_attributes(params[object_name])
      invoke_callbacks(:update, :after)
      flash[:notice] = I18n.t(:successfully_updated, :scope => object_name)
      respond_with(object, :location => collection_url)
    else
      render :edit
    end
  end

  def create
    invoke_callbacks(:create, :before)
    if object.save
      invoke_callbacks(:create, :after)
      flash[:notice] = I18n.t(:successfully_created, :scope => object_name)
      respond_with(object, :location => collection_url)
    else
      render :edit
    end
  end
  
  def destroy
    invoke_callbacks(:destroy, :before)
    if object.destroy
      invoke_callbacks(:destroy, :after)
      flash[:notice] = I18n.t(:successfully_removed, :scope => object_name)
      respond_to do |format|
        format.html { redirect_to collection_url }
        format.js   { render_js_for_destroy }
      end
    else
      redirect_to collection_url
    end

  end
 
  protected
  
  def self.create
    @@callbacks ||= {}
    @@callbacks[:create] ||= Spree::ActionCallbacks.new
  end
  
  def self.update
    @@callbacks ||= {}
    @@callbacks[:update] ||= Spree::ActionCallbacks.new
  end
  
  def self.destroy
    @@callbacks ||= {}
    @@callbacks[:destroy] ||= Spree::ActionCallbacks.new
  end

  def invoke_callbacks(action, callback_type)
    @@callbacks[action] ||= Spree::ActionCallbacks.new
    case callback_type.to_sym
      when :before then @@callbacks[action].before_methods.each {|method| send method }
      when :after  then @@callbacks[action].after_methods.each  {|method| send method }
    end
  end

  def render_js_for_destroy
    render :partial => "/admin/shared/destroy"
    flash.notice = nil
  end
  
  def model_class
    object_name.classify.constantize
  end
  
  def object_name
    controller_name.singularize
  end
  
  def collection
    @collection ||= instance_variable_get "@#{controller_name}"
  end
  
  def object
    @object ||= instance_variable_get "@#{object_name}"
  end

  # URL helpers

  def new_object_url(options = {})
    new_polymorphic_url([:admin, model_class], options)
  end
  
  def edit_object_url(object, options = {})
    edit_polymorphic_url([:admin, object], options)
  end
  
  def object_url(object = nil, options = {})
    if object
      polymorphic_url([:admin, object], options)
    else
      [:admin, @object]
    end
  end
  
  def collection_url(options = {})
    polymorphic_url([:admin, model_class], options)
  end
end
