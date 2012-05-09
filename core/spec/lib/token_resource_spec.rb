require 'spec_helper'

# Its pretty difficult to test this module in isolation b/c it needs to work in conjunction with an actual class that
# extends ActiveRecord::Base and has a corresponding table in the database.  So we'll just test it using Order instead
# since those classes are including the module.
describe Spree::TokenResource do
  let(:order) { Spree::Order.new }
  let(:permission) { mock_model(Spree::TokenizedPermission) }

  it 'should add has_one :tokenized_permission relationship' do
    assert Spree::Order.reflect_on_all_associations(:has_one).map(&:name).include?(:tokenized_permission)
  end

  context '#token' do
    it 'should return the token of the associated permission' do
      order.stub :tokenized_permission => permission
      permission.stub :token => 'foo'
      order.token.should == 'foo'
    end

    it 'should return nil if there is no associated permission' do
      order.token.should be_nil
    end
  end

  context '#create_token' do
    it 'should create a randomized 16 character token' do
      token = order.create_token
      token.size.should == 16
    end
  end
end