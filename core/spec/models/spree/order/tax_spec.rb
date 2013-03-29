require 'spec_helper'

module Spree
  describe Spree::Order do
    let(:order) { stub_model(Spree::Order) }

    context "#tax_zone" do
      let(:bill_address) { create :address }
      let(:ship_address) { create :address }
      let(:order) { Spree::Order.create(:ship_address => ship_address, :bill_address => bill_address) }
      let(:zone) { create :zone }

      context "when no zones exist" do
        before { Spree::Zone.destroy_all }

        it "should return nil" do
          order.tax_zone.should be_nil
        end
      end

      context "when :tax_using_ship_address => true" do
        before { Spree::Config.set(:tax_using_ship_address => true) }

        it "should calculate using ship_address" do
          Spree::Zone.should_receive(:match).at_least(:once).with(ship_address)
          Spree::Zone.should_not_receive(:match).with(bill_address)
          order.tax_zone
        end
      end

      context "when :tax_using_ship_address => false" do
        before { Spree::Config.set(:tax_using_ship_address => false) }

        it "should calculate using bill_address" do
          Spree::Zone.should_receive(:match).at_least(:once).with(bill_address)
          Spree::Zone.should_not_receive(:match).with(ship_address)
          order.tax_zone
        end
      end

      context "when there is a default tax zone" do
        before do
          @default_zone = create(:zone, :name => "foo_zone")
          Spree::Zone.stub :default_tax => @default_zone
        end

        context "when there is a matching zone" do
          before { Spree::Zone.stub(:match => zone) }

          it "should return the matching zone" do
            order.tax_zone.should == zone
          end
        end

        context "when there is no matching zone" do
          before { Spree::Zone.stub(:match => nil) }

          it "should return the default tax zone" do
            order.tax_zone.should == @default_zone
          end
        end
      end

      context "when no default tax zone" do
        before { Spree::Zone.stub :default_tax => nil }

        context "when there is a matching zone" do
          before { Spree::Zone.stub(:match => zone) }

          it "should return the matching zone" do
            order.tax_zone.should == zone
          end
        end

        context "when there is no matching zone" do
          before { Spree::Zone.stub(:match => nil) }

          it "should return nil" do
            order.tax_zone.should be_nil
          end
        end
      end
    end


    context "#exclude_tax?" do
      before do
        @order = create(:order)
        @default_zone = create(:zone)
        Spree::Zone.stub :default_tax => @default_zone
      end

      context "when prices include tax" do
        before { Spree::Config.set(:prices_inc_tax => true) }

        it "should be true when tax_zone is not the same as the default" do
          @order.stub :tax_zone => create(:zone, :name => "other_zone")
          @order.exclude_tax?.should be_true
        end

        it "should be false when tax_zone is the same as the default" do
          @order.stub :tax_zone => @default_zone
          @order.exclude_tax?.should be_false
        end
      end

      context "when prices do not include tax" do
        before { Spree::Config.set(:prices_inc_tax => false) }

        it "should be false" do
          @order.exclude_tax?.should be_false
        end
      end
    end
  end
end


