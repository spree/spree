require 'spec_helper'

describe 'Core extensions' do

  describe 'ActiveRecord::Base' do

    let(:order) { Spree::Order.create }

    context "update_attributes_without_callbacks" do

      it "sets the attributes" do
        order.update_attributes_without_callbacks :state => 'address', :email => 'spree@example.com'
        order.state.should == 'address'
        order.email.should == 'spree@example.com'
      end

      it "updates the attributes in the database" do
        order.update_attributes_without_callbacks :state => 'address', :email => 'spree@example.com'
        order.reload
        order.state.should == 'address'
        order.email.should == 'spree@example.com'
      end

      it "doesn't call valid" do
        order.should_not_receive(:valid?)
        order.update_attributes_without_callbacks :state => 'address', :email => 'spree@example.com'
      end

    end

  end

end
