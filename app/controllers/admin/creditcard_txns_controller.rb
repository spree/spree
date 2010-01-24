class Admin::CreditcardTxnsController < Admin::BaseController
  resource_controller
  belongs_to :creditcard
  actions :index
  before_filter :find_order
  
  def capture
    load_object
    begin
      @creditcard.capture(@creditcard_txn)
      flash[:notice] = t("credit_card_capture_complete")
    rescue Spree::GatewayError
      flash[:error] = t("unable_to_capture_credit_card")
    end
    redirect_to collection_path
  end
  
  def refund
    load_object
    if request.post?
      begin
        @creditcard.credit(params[:amount].to_f, @creditcard_txn)
        redirect_to collection_path
      rescue Spree::GatewayError => e
        flash.now[:error] = e.message
      end      
    end
  end

  def void
    load_object
    if request.post?
      begin
        @creditcard.void(@creditcard_txn)
      rescue Spree::GatewayError => e
        flash[:error] = e.message
      end      
      redirect_to collection_path
    end
  end  
  
  private
  
    def collection_path
      admin_order_creditcards_path(@order)
    end
    
    def find_order
      @order = Order.find_by_number(params[:order_id])
    end

end
