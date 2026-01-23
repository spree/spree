require 'spec_helper'

module Spree
  describe DataFeeds::Google::RequiredAttributes do
    subject { described_class.new }

    let(:store) { @default_store }
    let(:product) { create(:product, name: 'Test Product', stores: [store]) }

    describe '#call' do
      it 'does not mutate product name when generating titles for multiple variants' do
        option_type = create(:option_type)
        option_a = create(:option_value, name: 'option-a', option_type: option_type)
        option_b = create(:option_value, name: 'option-b', option_type: option_type)

        variant_a = create(:with_image_variant, product: product, option_values: [option_a])
        variant_b = create(:with_image_variant, product: product, option_values: [option_b])

        result_a = subject.call(product: product, variant: variant_a, store: store)
        result_b = subject.call(product: product, variant: variant_b, store: store)

        expect(result_a.value[:information]['title']).not_to include('option-b')
        expect(result_b.value[:information]['title']).not_to include('option-a')
      end

      it 'returns in stock for available products without available_on date' do
        product = create(:product, available_on: nil, status: 'active', stores: [store])
        variant = create(:with_image_variant, product: product)

        result = subject.call(product: product, variant: variant, store: store)

        expect(result.value[:information]['availability']).to eq('in stock')
      end
    end
  end
end
