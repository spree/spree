require 'spec_helper'

describe Spree::Store do

  describe "by_url" do 
    let!(:store)    { create(:store, url: "website1.com\nwww.subdomain.com") }
    let!(:store_2)  { create(:store, url: 'freethewhales.com') }

    it "should find stores by url" do
      by_domain = Spree::Store.by_url('www.subdomain.com')

      by_domain.should include(store)
      by_domain.should_not include(store_2)
    end
  end

  describe "default" do
    let!(:store)    { create(:store) }
    let!(:store_2)  { create(:store, default: true) }

    it "should ensure there is a default if one doesn't exist yet" do
      store.default.should be_true
    end

    it "should ensure there is only one default" do
      [store, store_2].each(&:reload)

      Spree::Store.where(default: true).count.should == 1
      store_2.default.should be_true
      store.default.should_not be_true
    end
  end

end
