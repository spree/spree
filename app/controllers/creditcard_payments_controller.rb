class CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :check_existing, :only => :new
  before_filter :validate_payment, :only => :create
  layout 'application'
  resource_controller :singleton
  
  belongs_to :order

  # override the r_c create since we need special logic to deal with the presenter in the create case
  def create
    creditcard_payment = CreditcardPayment.new(:order => @order)            
    creditcard_payment.creditcard = @payment_presenter.creditcard
    begin
      creditcard_payment.save
    rescue Exception => e
      flash[:error] = "Authorization Error: #{e.message}"
      render :action => "new" and return 
    end
=begin    
    @payment_presenter = PaymentPresenter.new(params[:payment_presenter])
    
    # check the validitiy of the 
#    set_image
    if @payment_presenter.save
      # associate the license with the asset (active_presenter doesn't handle associations)
      asset = @asset_presenter.asset
      asset.licenses << @asset_presenter.license
      asset.save

      format.html do
        flash[:notice] = 'Asset was successfully created.'
        redirect_to asset_url(asset)
      end
      format.js do
        responds_to_parent do
          render :update do |page|
            page.replace_html "validation_errors", ""              
            page['new_asset_popup'].down('form').reset
            page << "$('new_asset_popup').popup.hide();"
            page << "$('option_asset_identifier').value='" + asset.identifier + "';"
            page.visual_effect :highlight, 'option_asset_identifier', :duration => 8
            page << "$('message_popup').popup.hide();"
          end
        end
      end        
    else
      format.html do
        render :action => "new"
      end
      format.js do
        responds_to_parent do
          render :update do |page|
            page.replace_html "validation_errors", ""
            page.insert_html :top, "validation_errors", "<h4>Error Creating Asset</h4>"
            @asset_presenter.errors.full_messages.each do |message|
              page.insert_html :bottom, "validation_errors", "<li>#{message}</li>"
            end
            page << "$('message_popup').popup.show();"
          end
        end          
      end      
    end
=end
  end
    

  update.response do |wants|
    wants.html do 
      @order.next!
      redirect_to checkout_order_url(@order)
    end
  end

  def cvv
    render :layout => false
  end
  
  private
  def load_data
    @states = State.find(:all, :order => 'name')
    @countries = Country.find(:all)
  end

  def check_existing
    # TODO - redirect to the next step if there is no outstanding balance
  end

  def build_object
    @payment_presenter ||= PaymentPresenter.new(:address => parent_object.address)
  end
  
  def validate_payment
    # load the object so that its available to the form in the event of a validation error
    load_object
    load_payment_presenter
    render :action => "new" unless @payment_presenter.valid?
  end
  
  def load_payment_presenter
    payment_presenter = PaymentPresenter.new(params[:payment_presenter]) 
    payment_presenter.creditcard.first_name = payment_presenter.address.firstname
    payment_presenter.creditcard.last_name = payment_presenter.address.lastname
    @payment_presenter = payment_presenter
  end
end