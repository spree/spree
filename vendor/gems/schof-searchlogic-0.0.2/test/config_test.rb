require File.dirname(__FILE__) + '/test_helper.rb'

class ConfigTest < ActiveSupport::TestCase
  def test_per_page
    Searchlogic::Config.search.per_page = 1
    
    assert Account.count > 1
    assert Account.all.size > 1
    assert User.all.size > 1
    assert User.find(:all, :per_page => 1).size == 1
    assert User.new_search.all.size == 1
    assert User.new_search(:per_page => nil).all.size > 1
    
    Searchlogic::Config.search.per_page = nil
    
    assert Account.count > 1
    assert Account.all.size > 1
    assert User.all.size > 1
    assert User.find(:all, :per_page => 1).size == 1
    assert User.new_search.all.size > 1
    assert User.new_search(:per_page => 1).all.size == 1
  end
end