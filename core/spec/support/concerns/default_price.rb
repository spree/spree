shared_examples_for 'default_price' do
  subject(:instance) { FactoryBot.build(model.name.demodulize.downcase.to_sym) }

  let(:model) { described_class }

  describe '.has_one :default_price' do
    let(:default_price_association) { model.reflect_on_association(:default_price) }

    it 'is a has one association' do
      expect(default_price_association.macro).to eq :has_one
    end

    it 'has a dependent destroy' do
      expect(default_price_association.options[:dependent]).to eq :destroy
    end

    it 'has the class name of Spree::Price' do
      expect(default_price_association.options[:class_name]).to eq 'Spree::Price'
    end
  end

  describe '#default_price' do
    it { expect(instance.default_price.class).to eql Spree::Price }

    it 'delegates price' do
      expect(instance.default_price).to receive(:price)
      instance.price
    end

    it 'delegates price_including_vat_for' do
      expect(instance.default_price).to receive(:price_including_vat_for)
      instance.price_including_vat_for
    end
  end

  it { expect(instance.has_default_price?).to be_truthy }
end
