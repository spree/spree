require 'spec_helper'

describe Spree::PaymentMethod do
  describe "#available" do
    before(:all) do
      Spree::PaymentMethod.delete_all

      [nil, 'both', 'front_end', 'back_end'].each do |display_on|
        Spree::Gateway::Test.create(
          :name => 'Display Both',
          :display_on => display_on,
          :active => true,
          :environment => 'test',
          :description => 'foofah'
        )
      end
      Spree::PaymentMethod.all.size.should == 4
    end

    it "should return all methods available to front-end/back-end when no parameter is passed" do
      Spree::PaymentMethod.available.size.should == 2
    end

    it "should return all methods available to front-end/back-end when display_on = :both" do
      Spree::PaymentMethod.available(:both).size.should == 2
    end

    it "should return all methods available to front-end when display_on = :front_end" do
      Spree::PaymentMethod.available(:front_end).size.should == 2
    end

    it "should return all methods available to back-end when display_on = :back_end" do
      Spree::PaymentMethod.available(:back_end).size.should == 2
    end
  end

  describe '#auto_capture?' do
    class TestGateway < Spree::Gateway
      def provider_class
        Provider
      end
    end

    let(:gateway) { TestGateway.new }

    subject { gateway.auto_capture? }

    context 'when auto_capture is nil' do
      before(:each) do
        Spree::Config.should_receive('[]').with(:auto_capture).and_return(auto_capture)
      end

      context 'and when Spree::Config[:auto_capture] is false' do
        let(:auto_capture) { false }

        it 'should be false' do
          gateway.auto_capture.should be_nil
          subject.should be_false
        end
      end

      context 'and when Spree::Config[:auto_capture] is true' do
        let(:auto_capture) { true }

        it 'should be true' do
          gateway.auto_capture.should be_nil
          subject.should be_true
        end
      end
    end

    context 'when auto_capture is not nil' do
      before(:each) do
        gateway.auto_capture = auto_capture
      end

      context 'and is true' do
        let(:auto_capture) { true }

        it 'should be true' do
          subject.should be_true
        end
      end

      context 'and is false' do
        let(:auto_capture) { false }

        it 'should be true' do
          subject.should be_false
        end
      end
    end
  end

end
