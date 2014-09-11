require 'spec_helper'

describe Spree::Store do

  describe ".by_url" do 
    let!(:store)    { create(:store, url: "website1.com\nwww.subdomain.com") }
    let!(:store_2)  { create(:store, url: 'freethewhales.com') }

    it "should find stores by url" do
      by_domain = Spree::Store.by_url('www.subdomain.com')

      by_domain.should include(store)
      by_domain.should_not include(store_2)
    end
  end

  describe '.current' do
    let!(:store_1) { create(:store, default: true, url: 'spreecommerce.com') }
    let!(:store_2) { create(:store, default: false, url: 'www.subdomain.com') }

    it 'should return default when no domain' do
      expect(subject.class.current).to eql(store_1)
    end

    it 'should return store for domain' do
      expect(subject.class.current('spreecommerce.com')).to eql(store_1)
      expect(subject.class.current('www.subdomain.com')).to eql(store_2)
    end
  end

  describe ".default" do
    let!(:store)    { create(:store) }
    let!(:store_2)  { create(:store, default: true) }

    it "should ensure there is a default if one doesn't exist yet" do
      store.default.should be true
    end

    it "should ensure there is only one default" do
      [store, store_2].each(&:reload)

      Spree::Store.where(default: true).count.should == 1
      store_2.default.should be true
      store.default.should_not be true
    end
  end

end
