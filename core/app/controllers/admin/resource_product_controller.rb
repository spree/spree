class Admin::ResourceProductController < Admin::ResourceController
  protected
  
  def product
    @product ||= Product.find_by_permalink(params[:product_id])
  end
  
  def collection
    product.send(controller_name)
  end
  
  def build_resource
    product.send(controller_name).build(params[object_name])
  end
  
  def find_resource
    product.send(controller_name).find(params[:id])
  end

  # URL helpers

  def new_object_url(options = {})
    new_polymorphic_url([:admin, @product, model_class], options)
  end
  
  def edit_object_url(object, options = {})
    #edit_polymorphic_url([:admin, object], options)
    send "edit_admin_product_#{object_name}_url", @product, object, options
  end
  
  def object_url(object = nil, options = {})
    if object
      #polymorphic_url([:admin, object], options)
      send "admin_product_#{object_name}_url", @product, object, options
    else
      #[:admin, @object]
      send "admin_product_#{object_name}_url", @product, @object
    end
  end
  
  def collection_url(options = {})
    polymorphic_url([:admin, @product, model_class], options)
  end
end
