class Admin::VariantsController < Admin::BaseController
  resource_controller
  belongs_to :product

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => !request.xhr?}
  end

  create.before :create_before

  # redirect to index (instead of r_c default of show view)
  create.response do |wants|
    wants.html {redirect_to collection_url}
  end

  # redirect to index (instead of r_c default of show view)
  update.response do |wants|
    wants.html {redirect_to collection_url}
  end

  # override the destory method to set deleted_at value
  # instead of actually deleting the product.
  def destroy
    @variant = Variant.find(params[:id])

    @variant.deleted_at = Time.now()
    if @variant.save
      flash.notice = I18n.t("notice_messages.variant_deleted")
    else
      flash.notice = I18n.t("notice_messages.variant_not_deleted")
    end

    respond_to do |format|
      format.html { redirect_to admin_product_variants_url(params[:product_id]) }
      format.js  { render_js_for_destroy }
    end
  end

  private
  def create_before
    option_values = params[:new_variant]
    option_values.each_value {|id| @object.option_values << OptionValue.find(id)}
    @object.save
  end

  def collection
    @deleted =  (params.key?(:deleted)  && params[:deleted] == "on") ? "checked" : ""

    if @deleted.blank?
      @collection ||= end_of_association_chain.active.all
    else
      @collection ||= end_of_association_chain.deleted.all
    end
  end
end
