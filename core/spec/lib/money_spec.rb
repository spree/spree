#encoding: UTF-8
require 'spec_helper'

module Spree
  describe Money do
    before do
      reset_spree_preferences do |config|
        config.currency = "USD"
        config.currency_symbol_position = :before
        config.display_currency = false
      end
    end

    it "formats correctly" do
      money = Spree::Money.new(10)
      money.to_s.should == "$10.00"
    end

    context "with currency" do
      it "passed in option" do
        money = Spree::Money.new(10, :with_currency => true)
        money.to_s.should == "$10.00 USD"
      end

      it "config option" do
        Spree::Config[:display_currency] = true
        money = Spree::Money.new(10)
        money.to_s.should == "$10.00 USD"
      end
    end

    context "symbol positioning" do
      it "passed in option" do
        money = Spree::Money.new(10, :symbol_position => :after)
        money.to_s.should == "10.00 $"
      end

      it "passed in option string" do
        money = Spree::Money.new(10, :symbol_position => "after")
        money.to_s.should == "10.00 $"
      end

      it "config option" do
        Spree::Config[:currency_symbol_position] = :after
        money = Spree::Money.new(10)
        money.to_s.should == "10.00 $"
      end
    end

    context "JPY" do
      before do
        reset_spree_preferences do |config|
          config.currency = "JPY"
          config.currency_symbol_position = :before
          config.display_currency = false
        end
      end

      it "formats correctly" do
        money = Spree::Money.new(1000)
        money.to_s.should == "¥1,000"
      end
    end
  end
end
