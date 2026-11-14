require 'spec_helper'

# Constant aliases for classes renamed in 6.0. Each warns once, when its file
# first loads, so the file is loaded again here to see the warning.
RSpec.describe 'renamed class aliases' do
  {
    'Shipment' => ['Spree::Fulfillment', 'app/models/spree/shipment.rb'],
    'ShippingMethod' => ['Spree::DeliveryMethod', 'app/models/spree/shipping_method.rb'],
    'Prototype' => ['Spree::ProductType', 'app/models/spree/prototype.rb']
  }.each do |legacy_name, (replacement, path)|
    describe "Spree::#{legacy_name}" do
      it "is #{replacement}" do
        allow(Spree::Deprecation).to receive(:warn)

        expect(Spree.const_get(legacy_name)).to equal(replacement.constantize)
      end

      it 'warns with the replacement and the removal release when its file loads' do
        allow(Spree::Deprecation).to receive(:warn)
        Spree.const_get(legacy_name)
        Spree.send(:remove_const, legacy_name)

        expect(Spree::Deprecation).to receive(:warn).with(/Spree::#{legacy_name} is deprecated.*Spree 6\.3.*#{replacement}/)

        load Spree::Core::Engine.root.join(path).to_s
      end
    end
  end

  describe 'Spree::Store#default_country_iso_code' do
    it 'warns with the removal release and returns the default country code' do
      store = build(:store)

      expect(Spree::Deprecation).to receive(:warn).with(/default_country_iso_code is deprecated.*Spree 6\.3/)
      expect(store.default_country_iso_code).to eq(store.default_country_code)
    end
  end
end
