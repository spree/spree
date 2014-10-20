require 'spec_helper'

module Spree
  module Stock
    describe Packer, :type => :model do
      let!(:inventory_units) { 5.times.map { build(:inventory_unit) } }
      let(:stock_location) { create(:stock_location) }

      subject { Packer.new(stock_location, inventory_units) }

      context 'packages' do
        it 'builds an array of packages' do
          packages = subject.packages
          expect(packages.size).to eq 1
          expect(packages.first.contents.size).to eq 5
        end

        it 'allows users to set splitters to an empty array' do
          packages = Packer.new(stock_location, inventory_units, []).packages
          expect(packages.size).to eq 1
        end
      end

      context 'default_package' do
        it 'contains all the items' do
          package = subject.default_package
          expect(package.contents.size).to eq 5
        end

        it 'variants are added as backordered without enough on_hand' do
          expect(stock_location).to receive(:fill_status).exactly(5).times.and_return(
            *(Array.new(3, [1,0]) + Array.new(2, [0,1]))
          )

          package = subject.default_package
          expect(package.on_hand.size).to eq 3
          expect(package.backordered.size).to eq 2
        end

        context "location doesn't have order items in stock" do
          let(:stock_location) { create(:stock_location, propagate_all_variants: false) }
          let(:packer) { Packer.new(stock_location, inventory_units) }

          it "builds an empty package" do
            expect(packer.default_package.contents).to be_empty
          end
        end

        context "doesn't track inventory levels" do
          let(:variant) { build(:variant) }
          let(:inventory_units) { 30.times.map { build(:inventory_unit, variant: variant) } }

          before { Config.track_inventory_levels = false }

          it "doesn't bother stock items status in stock location" do
            expect(subject.stock_location).not_to receive(:fill_status)
            subject.default_package
          end

          it "still creates package with proper quantity" do
            expect(subject.default_package.quantity).to eql 30
          end
        end
      end
    end
  end
end
