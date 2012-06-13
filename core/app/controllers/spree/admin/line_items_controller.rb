module Spree
  module Admin
    class LineItemsController < Spree::Admin::BaseController

      before_filter :load_order
      before_filter :load_line_item, :only => [:destroy, :update]

      respond_to :html, :js

      def create
        variant = Variant.find(params[:line_item][:variant_id])
        @line_item = @order.add_variant(variant, params[:line_item][:quantity].to_i)

        if @order.save
          respond_with(@line_item) do |format|
            format.html { render :partial => 'spree/admin/orders/form', :locals => { :order => @order.reload }, :layout => false }
          end
        else
          respond_with(@line_item) do |format|
            format.js { render :action => 'create', :locals => { :order => @order.reload }, :layout => false }
          end
        end
      end

      def destroy
        if @line_item.destroy
          @order.reload
          respond_with(@line_item) do |format|
            format.html { render :partial => 'spree/admin/orders/form', :locals => { :order => @order }, :layout => false }
          end
        else
          respond_with(@line_item) do |format|
            format.html { render :partial => 'spree/admin/orders/form', :locals => { :order => @order }, :layout => false }
          end
        end
      end

      def new
        respond_with do |format|
          format.html { render :action => :new, :layout => false }
        end
      end

      def update
        if @line_item.update_attributes(params[:line_item])
          respond_with(@line_item) do |format|
            format.html { render :partial => 'spree/admin/orders/form', :locals => { :order => @order.reload }, :layout => false}
          end
        else
          respond_with(@line_item) do |format|
            format.html { render :partial => 'spree/admin/orders/form', :locals => { :order => @order.reload }, :layout => false}
          end
        end
      end

      def load_order
        @order = Order.find_by_number! params[:order_id]
      end

      def load_line_item
        @line_item = @order.line_items.find params[:id]
      end
    end
  end
end
