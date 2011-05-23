class Admin::VariantsController < Admin::ResourceController
  belongs_to :product, :find_by => :permalink
  create.before :create_before

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

    respond_with(@variant) do |format|
      format.html { redirect_to admin_product_variants_url(params[:product_id]) }
      format.js  { render_js_for_destroy }
    end
  end

  def update_positions
    params[:positions].each do |id, index|
      Variant.update_all(['position=?', index], ['id=?', id])
    end

    respond_with(@variant) do |format|
      format.html { redirect_to admin_product_variants_url(params[:product_id]) }
      format.js  { render :text => 'Ok' }
    end
  end

  protected
  def create_before
    option_values = params[:new_variant]
    option_values.each_value {|id| @object.option_values << OptionValue.find(id)}
    @object.save
  end

  def collection
    @deleted = (params.key?(:deleted)  && params[:deleted] == "on") ? "checked" : ""

    if @deleted.blank?
      @collection ||= super
    else
      @collection ||= Variant.where(:product_id => parent.id).deleted
    end
    @collection
  end
end
