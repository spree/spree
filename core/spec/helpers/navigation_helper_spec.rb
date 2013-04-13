# coding: UTF-8
require 'spec_helper'

describe Spree::Admin::NavigationHelper do

  describe "#tab" do
    before do
      helper.stub(:cannot?).and_return false
    end

    context "creating an admin tab" do
      it "should capitalize the first letter of each word in the tab's label" do
        admin_tab = helper.tab(:orders)
        admin_tab.should include("Orders")
      end
    end

    it "should accept options with label and capitalize each word of it" do
      admin_tab = helper.tab(:orders, :label => "delivered orders")
      admin_tab.should include("Delivered Orders")
    end

    it "should capitalize words with unicode characters" do
      # overview
      admin_tab = helper.tab(:orders, :label => "přehled")
      admin_tab.should include("Přehled")
    end
  end

  describe '#klass_for' do

    it 'returns correct klass for Spree model' do
      klass_for(:products).should == Spree::Product
      klass_for(:product_properties).should == Spree::ProductProperty
    end

    it 'returns correct klass for non-spree model' do
      class MyUser
      end
      klass_for(:my_users).should == MyUser

      Object.send(:remove_const, 'MyUser')
    end

    it 'returns correct namespaced klass for non-spree model' do
      module My
        class User
        end
      end

      klass_for(:my_users).should == My::User

      My.send(:remove_const, 'User')
      Object.send(:remove_const, 'My')
    end

  end

end