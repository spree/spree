require 'spec_helper'

describe Spree::Order do
  let(:order) { Spree::Order.new }

  context '#associate_user!' do
    let(:user) { mock_model Spree::User, :email => 'spree@example.com', :anonymous? => false }
    before { order.stub(:save! => true) }

    it 'should associate the order with the specified user' do
      order.associate_user! user
      order.user.should == user
    end

    it "should set the order's email attribute to that of the specified user" do
      order.associate_user! user
      order.email.should == user.email
    end

    it 'should destroy any previous association with a guest user' do
      guest_user = mock_model Spree::User
      order.user = guest_user
      order.associate_user! user
      order.user.should_not == guest_user
    end
  end

  context 'with bogus email' do
    it 'should not be valid' do
      order.stub(:new_record? => false)
      order.email = 'foo'
      order.state = 'address'
      order.should_not be_valid
    end
  end

  context '#create' do
    it 'should create a token permission' do
      order.save
      order.token.should_not be_nil
    end
  end
end
