class Admin::CreditcardsController < Admin::BaseController
  resource_controller
  belongs_to :order
  actions :index
  
  def refund
    load_object
    @creditcard_txn = CreditcardTxn.find(params[:txn_id])
    
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
    @creditcard_txn = CreditcardTxn.find(params[:txn_id])
    
    if request.post?
      begin
        @creditcard.void(@creditcard_txn)
      rescue Spree::GatewayError => e
        flash[:error] = e.message
      end      
      redirect_to collection_path
    end
  end  
  
end
