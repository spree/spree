class Admin::ReturnAuthorizationsController < Admin::BaseController
  resource_controller
  belongs_to :order

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }
  destroy.success.wants.js { render_js_for_destroy }

  update.after :associate_inventory_units
  create.after :associate_inventory_units

  def fire
    load_object
    @return_authorization.send("#{params[:e]}!")
    flash.notice = t('return_authorization_updated')
    redirect_to :back
  end

  private
    def associate_inventory_units
      params[:return_quantity].each { |variant_id, qty| @return_authorization.add_variant(variant_id.to_i, qty.to_i) }
    end
end
