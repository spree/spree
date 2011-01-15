require File.dirname(__FILE__) + '/../spec_helper'

describe 'Core extensions' do

  describe 'ActiveRecord::Base' do

    let(:order) { Order.create }

    context "update_attribute_without_callbacks" do

      it "sets the attribute" do
        order.update_attribute_without_callbacks 'state', 'new_state'
        order.state.should == 'new_state'
      end

      it "updates the attribute in the database" do
        order.update_attribute_without_callbacks 'state', 'new_state'
        order.reload
        order.state.should == 'new_state'
      end

      it "doesn't call valid" do
        order.should_not_receive(:valid?)
        order.update_attribute_without_callbacks 'state', 'new_state'
      end

    end

    context "updte_attributes_without_callbacks" do

      it "sets the attributes" do
        order.update_attributes_without_callbacks :state => 'new_state', :email => 'spree@example.com'
        order.state.should == 'new_state'
        order.email.should == 'spree@example.com'
      end

      it "updates the attributes in the database" do
        order.update_attributes_without_callbacks :state => 'new_state', :email => 'spree@example.com'
        order.reload
        order.state.should == 'new_state'
        order.email.should == 'spree@example.com'
      end

      it "doesn't call valid" do
        order.should_not_receive(:valid?)
        order.update_attributes_without_callbacks :state => 'new_state', :email => 'spree@example.com'
      end

    end

  end

end
