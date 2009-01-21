class Admin::ReportsController < Admin::BaseController
  before_filter :load_data  
  
  AVAILABLE_REPORTS = {
    :sales_total => {:name => "Sales Total", :description => "Sales Total For All Orders"}
  }

  def index
    @reports = AVAILABLE_REPORTS
  end
  
  def sales_total    
    scope = Order.scoped({})
    scope = scope.between(@filter.start, (@filter.stop.blank? ? @default_stop : @filter.stop.to_date + 1 )) unless @filter.start.blank?

    @orders = scope.find(:all, :order => 'orders.created_at DESC', :page => {:size => Spree::Config[:orders_per_page], :current =>params[:p], :first => 1})    

    @item_total = scope.sum(:item_total)
    @ship_total = scope.sum(:ship_amount)
    @tax_total = scope.sum(:tax_amount)
    @sales_total = scope.sum(:total)
  end

  private 
  def load_data
    @filter = params.has_key?(:filter) ? OrderFilter.new(params[:filter]) : OrderFilter.new
    unless @filter.valid?
      flash.now[:error] = t('invalid_search')
      return nil
    end
    @default_stop = (Date.today + 1).to_s(:db)    
  end  

end