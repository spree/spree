class Admin::CreditcardsController < Admin::BaseController
  resource_controller
  belongs_to :order
  actions :index
  
  def refund
    puts params.inspect
    load_object
    @creditcard_txn = CreditcardTxn.find(params[:txn_id])
    
    puts @creditcard_txn.inspect
    if request.post?
#      @creditcard.credit(params[:amount].to_f, @creditcard_txn)
#      redirect_to collection_path
    end
  end
  
end
