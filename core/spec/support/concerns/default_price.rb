shared_examples_for "default_price" do
  let(:model)        { described_class }
  subject(:instance) { FactoryGirl.build(model.name.demodulize.downcase.to_sym) }

  describe '.has_one :default_price' do
    let(:default_price_association) { model.reflect_on_association(:default_price) }

    it 'should be a has one association' do
      expect(default_price_association.macro).to eql :has_one
    end

    it 'should have a dependent destroy' do
      expect(default_price_association.options[:dependent]).to eql :destroy
    end

    it 'should have the class name of Spree::Price' do
      expect(default_price_association.options[:class_name]).to eql 'Spree::Price'
    end
  end

  describe '#default_price' do
    subject { instance.default_price }

    its(:class) { should eql Spree::Price }
    it 'delegates price' do
      expect(instance.default_price). to receive(:price)
      instance.price
    end

    it 'delegates price_including_vat_for' do
      expect(instance.default_price). to receive(:price_including_vat_for)
      instance.price_including_vat_for
    end
  end

  its(:has_default_price?) { should be_truthy }
end
