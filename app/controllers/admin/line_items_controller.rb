class Admin::LineItemsController < Admin::BaseController
  resource_controller
  belongs_to :order
  ssl_required
  actions :all, :except => :index

  before_filter :check_order_contains, :only => :create

  destroy.success.wants.html { render :partial => "admin/orders/form", :locals => {:order => @order}, :layout => false }

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  create.response do |wants|
    wants.html { render :partial => "admin/orders/form", :locals => {:order => @order}, :layout => false}
  end

  update.response do |wants|
    wants.html { render :partial => "admin/orders/form", :locals => {:order => @order}, :layout => false}
  end

  destroy.after :recalulate_totals
  update.after :recalulate_totals
  create.after :recalulate_totals

  private
  def check_order_contains
    variant = Variant.find(params[:line_item][:variant_id])
    @order = Order.find_by_number(params[:order_id])

    if @order.contains?(variant)
      @order.add_variant(variant, params[:line_item][:quantity].to_i)
      @order.save

      render :partial => "admin/orders/form", :locals => {:order => @order}, :layout => false
    end
  end

  def recalulate_totals
    unless @order.shipping_method.nil?
      @order.shipping_charges.each do |shipping_charge|
        shipping_charge.update_attributes(:amount => @order.shipping_method.calculate_cost(@order.shipment))
      end
    end

    @order.tax_charges.each do |tax_charge|
      tax_charge.update_attributes(:amount => tax_charge.calculate_tax_charge)
    end

    @order.update_totals(true)
    @order.save

  end
end
