require File.dirname(__FILE__) + '/../test_helper'

class ExpiryDateTest < Test::Unit::TestCase
  def test_should_be_expired
    last_month = 2.months.ago
    date = CreditCard::ExpiryDate.new(last_month.month, last_month.year)
    assert date.expired?
  end
  
  def test_today_should_not_be_expired
    today = Time.now
    date = CreditCard::ExpiryDate.new(today.month, today.year)
    assert_false date.expired?
  end
  
  def test_dates_in_the_future_should_not_be_expired
    next_month = 1.month.from_now
    date = CreditCard::ExpiryDate.new(next_month.month, next_month.year)
    assert_false date.expired?
  end
end