require 'spec_helper'

describe Spree::PaymentMethod do

  context 'validation' do
    it { should have_valid_factory(:payment_method) }
  end

  describe "#available" do
    before(:all) do
      Spree::PaymentMethod.delete_all

      [nil, 'both', 'front_end', 'back_end'].each do |display_on|
        Spree::Gateway::Test.create({:name => 'Display Both', :display_on => display_on,
           :active => true, :environment => 'test', :description => 'foofah'}, :without_protection => true)
      end
      Spree::PaymentMethod.all.size.should == 4
    end

    it "should return all methods available to front-end/back-end when no parameter is passed" do
      Spree::PaymentMethod.available.size.should == 2
    end

    it "should return all methods available to front-end/back-end when display_on = :both" do
      pending
      Spree::PaymentMethod.available(:both).size.should == 2
    end

    it "should return all methods available to front-end when display_on = :front_end" do
      pending
      Spree::PaymentMethod.available(:front_end).size.should == 2
    end

    it "should return all methods available to back-end when display_on = :back_end" do
      pending
      Spree::PaymentMethod.available(:back_end).size.should == 2
    end
  end

end
