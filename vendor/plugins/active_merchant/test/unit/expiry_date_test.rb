require 'test_helper'

class ExpiryDateTest < Test::Unit::TestCase
  def test_should_be_expired
    last_month = 2.months.ago
    date = CreditCard::ExpiryDate.new(last_month.month, last_month.year)
    assert date.expired?
  end
  
  def test_today_should_not_be_expired
    today = Time.now.utc
    date = CreditCard::ExpiryDate.new(today.month, today.year)
    assert_false date.expired?
  end
  
  def test_dates_in_the_future_should_not_be_expired
    next_month = 1.month.from_now
    date = CreditCard::ExpiryDate.new(next_month.month, next_month.year)
    assert_false date.expired?
  end
  
  def test_invalid_date
    expiry = CreditCard::ExpiryDate.new(13, 2009)
    assert_equal Time.at(0).utc, expiry.expiration
  end
  
  def test_month_and_year_coerced_to_integer
    expiry = CreditCard::ExpiryDate.new("13", "2009")
    assert_equal 13, expiry.month
    assert_equal 2009, expiry.year
  end
end