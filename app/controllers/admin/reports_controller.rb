class Admin::ReportsController < Admin::BaseController
  
  AVAILABLE_REPORTS = {
    :sales_total => {:name => "Sales Total", :description => "Sales Total For All Orders"}
  }

  def index
    @reports = AVAILABLE_REPORTS
  end
  
  def sales_total
    c = build_conditions
    @item_total = Order.sum(:item_total, :conditions => c)
    @ship_total = Order.sum(:ship_amount, :conditions => c)
    @tax_total = Order.sum(:tax_amount, :conditions => c)
    @sales_total = Order.sum(:total, :conditions => c)
  end

  private 
  
      def date_conditions
        return nil unless params[:search]
        
        @search = SearchCriteria.new(params[:search])
        
        unless @search.valid?
          flash.now[:error] = "Invalid search criteria.  Please check your results."
          return nil
        end

        p = {}
        c = []
        if not @search.start.blank?
          c << "(orders.created_at between :start and :stop)"
          p.merge! :start => @search.start.to_date
          @search.stop = Date.today + 1 if @search.stop.blank?
          p.merge! :stop => @search.stop.to_date + 1.day 
        end
        
        return nil if c.empty? 
        
        {:conditions => c, :parameters => p}
      end
  
      def build_conditions
        dc = date_conditions
        return nil if dc.nil?
        c = dc[:conditions]
        p = dc[:parameters]
        [(c.to_sentence :skip_last_comma=>true).gsub(",", " and "), p]
      end
end