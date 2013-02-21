require 'spec_helper'

module Spree
  module Stock
    describe Estimator do
      let!(:shipping_method) { create(:shipping_method_with_category) }
      let(:shipping_category) { shipping_method.shipping_category }
      let(:package) { build(:stock_package_fulfilled) }
      let(:order) { package.order }
      subject { Estimator.new(order) }

      it 'returns packages with shipping rates' do
        package.should_receive(:shipping_category).and_return(shipping_category)
        ShippingMethod.any_instance.stub_chain(:calculator, :compute).and_return(4.00)

        shipping_rates = subject.shipping_rates(package)
        shipping_rates.first.cost.should eq 4.00
      end
    end
  end
end
