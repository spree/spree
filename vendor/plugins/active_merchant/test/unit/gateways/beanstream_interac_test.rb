require 'test_helper'

class BeanstreamInteracTest < Test::Unit::TestCase
  def setup
    @gateway = BeanstreamInteracGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @options)

    assert_success response
    assert_equal "R", response.params["responseType"]
    assert response.params["pageContents"]
    assert_equal response.params["pageContents"], response.redirect
  end
  
  def test_successful_confirmation
    @gateway.expects(:ssl_post).returns(successful_confirmation_response)

    response = @gateway.confirm(successful_return_from_interac_online)
    assert response.success?
    assert_equal "Approved", response.message
    assert_equal "10000029;5.00;P", response.authorization
  end

  private
  
  def successful_purchase_response
    "responseType=R&pageContents=%3CHTML%3E%3CHEAD%3E%3C%2FHEAD%3E%3CBODY%3E%3CFORM%20action%3D%22https%3A%2F%2Fpayments%2Ebeanstream%2Ecom%2FiOnlineEmulator%2Fgateway%2Easp%22%20method%3DPOST%20id%3DfrmIOnline%20name%3DfrmIOnline%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FMERCHNUM%22%20%20value%3D%2210010162199999%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FAMOUNT%22%20%20value%3D%221500%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FTERMID%22%20value%3D%2262199999%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FCURRENCY%22%20value%3D%22CAD%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FINVOICE%22%20value%3D%221be7db7a129b07ac5f7e%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FMERCHDATA%22%20value%3D%226CE36AF7%2D5013%2D4B94%2DB740153714A41962%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FFUNDEDURL%22%20value%3D%22https%3A%2F%2Fwww%2Ebeanstream%2Ecom%2Fscripts%2Fprocess%5Ftransaction%5Fauth%2Easp%3F%26funded%3D1%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FNOTFUNDEDURL%22%20value%3D%22https%3A%2F%2Fwww%2Ebeanstream%2Ecom%2Fscripts%2Fprocess%5Ftransaction%5Fauth%2Easp%3F%26funded%3D0%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22merchant%5Fname%22%20value%3D%22Cody%20Fauser%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22referHost%22%20value%3D%22https%3A%2F%2Fwww%2Ebeanstream%2Ecom%2Fscripts%2Fprocess%5Ftransaction%2Easp%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22referHost2%22%20value%3D%22https%3A%2F%2Fwww%2Ecatnrose%2Ecom%2Fioxml%2Easp%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22referHost3%22%20value%3D%22%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FMERCHLANG%22%20value%3D%22en%22%3E%3Cinput%20type%3D%22hidden%22%20name%3D%22IDEBIT%5FVERSION%22%20value%3D%221%22%3E%3C%2FFORM%3E%3CSCRIPT%20language%3D%22JavaScript%22%3Edocument%2EfrmIOnline%2Esubmit%28%29%3B%3C%2FSCRIPT%3E%3C%2FBODY%3E%3C%2FHTML%3E"
  end
  
  def successful_return_from_interac_online
    "bank_choice=1&merchant_name=Billing+Boss+IO+SB&confirmValue=&headerText=&IDEBIT_MERCHDATA=C4B50A48-6E11-4C21-A31EF4A602BC0099&IDEBIT_INVOICE=18face21593b59c7bb7e&IDEBIT_AMOUNT=1500&IDEBIT_FUNDEDURL=http%3A%2F%2Febay.massapparel.com%3A8000%2Finterac%2Ffunded%3Ffunded%3D1&IDEBIT_NOTFUNDEDURL=http%3A%2F%2Febay.massapparel.com%3A8000%2Finterac%2Fnotfunded%3Ffunded%3D0&IDEBIT_ISSLANG=en&IDEBIT_TRACK2=3728024906540591214%3D12010123456789XYZ&IDEBIT_ISSCONF=CONF%23TEST&IDEBIT_ISSNAME=TestBank1&IDEBIT_VERSION=1&accountType=Chequing"
  end
  
  def successful_confirmation_response
    "trnApproved=1&trnId=10000029&messageId=1&messageText=Approved&trnOrderNumber=f29d2406b49b239b6dfb5db1f642b2&authCode=TEST&errorType=N&errorFields=&responseType=T&trnAmount=5%2E00&trnDate=6%2F8%2F2008+3%3A17%3A12+PM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+for+this+transaction%2E&trnType=P&paymentMethod=IO&ioConfCode=CONF%23TEST&ioInstName=TestBank1&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end
end
