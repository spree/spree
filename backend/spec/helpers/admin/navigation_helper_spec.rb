# coding: UTF-8
require 'spec_helper'

module Spree
  describe Admin::NavigationHelper do
    describe "#tab" do
      context "creating an admin tab" do
        it "should capitalize the first letter of each word in the tab's label" do
          admin_tab = tab(:orders)
          admin_tab.should include("Orders")
        end
      end

      it "should accept options with label and capitalize each word of it" do
        admin_tab = tab(:orders, :label => "delivered orders")
        admin_tab.should include("Delivered Orders")
      end

      it "should capitalize words with unicode characters" do
        admin_tab = tab(:orders, :label => "přehled") # overview
        admin_tab.should include("Přehled")
      end
    end
  end
end
