class Admin::ResourceOrderController < Admin::ResourceController
  protected
  
  def order
    @order ||= Order.find_by_number(params[:order_id])
  end
  
  def collection
    order.send(controller_name)
  end
  
  def build_resource
    order.send(controller_name).build(params[object_name])
  end
  
  def find_resource
    order.send(controller_name).find(params[:id])
  end

  # URL helpers

  def new_object_url(options = {})
    new_polymorphic_url([:admin, @order, model_class], options)
  end
  
  def edit_object_url(object, options = {})
    #edit_polymorphic_url([:admin, object], options)
    send "edit_admin_order_#{object_name}_url", @order, object, options
  end
  
  def object_url(object = nil, options = {})
    if object
      #polymorphic_url([:admin, object], options)
      send "admin_order_#{object_name}_url", @order, object, options
    else
      #[:admin, @object]
      send "admin_order_#{object_name}_url", @order, @object
    end
  end
  
  def collection_url(options = {})
    polymorphic_url([:admin, @order, model_class], options)
  end
end
