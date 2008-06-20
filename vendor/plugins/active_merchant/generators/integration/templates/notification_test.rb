require File.dirname(__FILE__) + '/../../../test_helper'

class <%= class_name %>NotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @<%= name %> = <%= class_name %>::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @<%= name %>.complete?
    assert_equal "", @<%= name %>.status
    assert_equal "", @<%= name %>.transaction_id
    assert_equal "", @<%= name %>.item_id
    assert_equal "", @<%= name %>.gross
    assert_equal "", @<%= name %>.currency
    assert_equal "", @<%= name %>.received_at
    assert @<%= name %>.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @<%= name %>.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @<%= name %>.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end  
end
