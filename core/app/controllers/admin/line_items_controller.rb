class Admin::LineItemsController < Admin::BaseController
  resource_controller
  belongs_to :order

  actions :all, :except => :index

  create.flash nil
  update.flash nil
  destroy.flash nil

  #override r_c create action as we want to use order#add_variant instead of creating line_item
  def create
    load_object
    variant = Variant.find(params[:line_item][:variant_id])

    before :create

    @order.add_variant(variant, params[:line_item][:quantity].to_i)

    if @order.save
      after :create
      set_flash :create
      response_for :create
    else
      after :create_fails
      set_flash :create_fails
      response_for :create_fails
    end

  end

  destroy.success.wants.html { render :partial => "admin/orders/form", :locals => {:order => @order.reload}, :layout => false }
  destroy.failure.wants.html { render :partial => "admin/orders/form", :locals => {:order => @order.reload}, :layout => false }

  new_action.response do |wants|
    wants.html {render :action => :new, :layout => false}
  end

  create.response do |wants|
    wants.html { render :partial => "admin/orders/form", :locals => {:order => @order.reload}, :layout => false}
  end

  update.success.wants.html { render :partial => "admin/orders/form", :locals => {:order => @order.reload}, :layout => false}
  update.failure.wants.html { render :partial => "admin/orders/form", :locals => {:order => @order.reload}, :layout => false}

end
