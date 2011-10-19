require 'spec_helper'

describe Admin::NavigationHelper do
  describe "#tab" do
    context "creating an admin tab" do
      it "should capitalize the first letter of each word in the tab's label" do
        admin_tab = tab(:orders)
        admin_tab.should include("Orders")
      end
    end
  end
end
