require 'test_helper'

class ActionViewHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations::ActionViewHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  
  attr_accessor :output_buffer
  
  def setup
    @controller = Class.new do
      attr_reader :url_for_options
      def url_for(options, *parameters_for_method_reference)
        @url_for_options = options
      end      
    end
    @controller = @controller.new
    @output_buffer = ''
  end

  
  def test_basic_payment_service
    _erbout = ''

    payment_service_for('order-1','test', :service => :bogus){}

    expected = [
      '<form action="http://www.bogus.com" method="post">',
      '<input id="order" name="order" type="hidden" value="order-1" />',
      '<input id="account" name="account" type="hidden" value="test" />',
      "</form>"
    ]
   
    _erbout.each_line do |line|
      assert expected.include?(line.chomp), "Failed to match #{line}"
    end
  end
  
  def test_payment_service_no_block_given
    assert_raise(ArgumentError){ payment_service_for }
  end
  
  protected
  def protect_against_forgery?
    false
  end
end
