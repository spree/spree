OrdersController.class_eval do
  before_filter :check_authorization
  before_filter :discard_unauthorized_variants, :only => :populate

  private

  def check_authorization
    session[:access_token] ||= params[:token]
    order = current_order || Order.find_by_number(params[:id])

    if order
      authorize! :edit, order, session[:access_token]
    else
      authorize! :create, Order
    end
  end

  def discard_unauthorized_variants
    params[:products].each do |product_id,variant_id|
      product = Variant.find(variant_id).product
      params[:products].delete(product_id) if cannot? :show, product
    end if params[:products]

    params[:variants].each do |variant_id, quantity|
      product = Variant.find(variant_id).product
      params[:variants].delete(variant_id) if cannot? :show, product
    end if params[:variants]
  end

end
