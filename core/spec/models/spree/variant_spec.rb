require 'spec_helper'

describe Spree::Variant, type: :model do
  let(:store) { @default_store }
  let(:variant) { create(:variant, product: create(:base_product, stores: [store])) }
  let(:master_variant) { create(:master_variant) }

  it_behaves_like 'default_price'
  it_behaves_like 'metadata'
  it_behaves_like 'lifecycle events'

  context 'sorting' do
    it 'responds to set_list_position' do
      expect(variant.respond_to?(:set_list_position)).to eq(true)
    end
  end

  context 'validations' do
    it 'validates price is greater than 0' do
      variant.price = -1
      expect(variant).to be_invalid
    end

    it 'validates price is 0' do
      variant.price = 0
      expect(variant).to be_valid
    end

    context 'SKU' do
      describe 'normalizes' do
        it 'strips leading and trailing whitespace' do
          variant = build(:variant, sku: '  TEST-SKU  ')
          expect(variant.sku).to eq('TEST-SKU')
        end

        it 'preserves empty string (does not convert to nil)' do
          variant = build(:variant, sku: '   ')
          expect(variant.sku).to eq('')
        end
      end

      context 'default behaviour' do
        context 'invalid' do
          let(:variant_2) { build(:variant, sku: variant.sku) }

          it 'with the same SKU' do
            expect(variant_2.valid?).to eq(false)
          end
        end

        context 'valid' do
          let(:variant_2) { build(:variant, sku: 'OTHER-SKU') }

          it 'with different SKU' do
            expect(variant_2.valid?).to eq(true)
          end

          it 'without SKU' do
            variant_2.sku = ''
            expect(variant_2.valid?).to eq(true)
          end
        end
      end

      context 'disabled validation' do
        before do
          Spree::Config[:disable_sku_validation] = true
        end

        after do
          Spree::Config[:disable_sku_validation] = false
        end

        context 'valid' do
          let(:variant_2) { build(:variant, sku: 'OTHER-SKU') }

          it 'with the same SKU' do
            expect(variant_2.valid?).to eq(true)
          end

          it 'without SKU' do
            variant_2.sku = ''
            expect(variant_2.valid?).to eq(true)
          end
        end
      end
    end

    it 'validates the dimensions unit' do
      expect(build(:variant, dimensions_unit: nil)).to be_valid

      expect(build(:variant, dimensions_unit: 'mm')).to be_valid
      expect(build(:variant, dimensions_unit: 'cm')).to be_valid
      expect(build(:variant, dimensions_unit: 'in')).to be_valid
      expect(build(:variant, dimensions_unit: 'ft')).to be_valid

      expect(build(:variant, dimensions_unit: 'oz')).to be_invalid
      expect(build(:variant, dimensions_unit: 'lb')).to be_invalid
    end

    it 'validates the weight unit' do
      expect(build(:variant, weight_unit: nil)).to be_valid

      expect(build(:variant, weight_unit: 'g')).to be_valid
      expect(build(:variant, weight_unit: 'kg')).to be_valid
      expect(build(:variant, weight_unit: 'lb')).to be_valid
      expect(build(:variant, weight_unit: 'oz')).to be_valid

      expect(build(:variant, weight_unit: 'mm')).to be_invalid
      expect(build(:variant, weight_unit: 'ft')).to be_invalid
    end
  end

  context 'after create' do
    let!(:product) { create(:product, stores: [store]) }

    it 'propagate to stock items' do
      expect_any_instance_of(Spree::StockLocation).to receive(:propagate_variant)
      create(:variant, product: product)
    end

    context 'stock location has disable propagate all variants' do
      before { Spree::StockLocation.update_all propagate_all_variants: false }

      it 'propagate to stock items' do
        expect_any_instance_of(Spree::StockLocation).not_to receive(:propagate_variant)
        product.variants.create
      end
    end

    describe 'mark_master_out_of_stock' do
      before do
        product.master.stock_items.first.set_count_on_hand(5)
      end

      context 'when product is created without variants but with stock' do
        it { expect(product.master).to be_in_stock }
      end

      context 'when a variant is created' do
        let!(:new_variant) { create(:variant, product: product) }

        it { expect(product.master).not_to be_in_stock }
      end
    end

    describe '#create_default_stock_item' do
      let(:new_variant) { product.variants.create(track_inventory: track_inventory, is_master: true) }

      context 'when not tracking inventory' do
        let(:track_inventory) { false }

        it 'creates a default stock item' do
          new_variant

          expect(new_variant.reload.stock_items.count).to eq(1)
          expect(new_variant.stock_items[0].count_on_hand).to eq(0)
          expect(new_variant.stock_items[0].backorderable).to eq(false)
        end

        context 'when variant is created along with a stock item' do
          let(:new_variant) do
            product.variants.create(
              track_inventory: track_inventory,
              is_master: true,
              stock_items_attributes: {
                '0' => {
                  stock_location_id: create(:stock_location).id,
                  count_on_hand: 10,
                  backorderable: true
                }
              }
            )
          end

          it 'does not create an another stock item' do
            new_variant

            expect(new_variant.reload.stock_items.count).to eq(1)
            expect(new_variant.stock_items[0].count_on_hand).to eq(10)
            expect(new_variant.stock_items[0].backorderable).to eq(true)
          end
        end
      end

      context 'when tracking inventory' do
        let(:track_inventory) { true }

        it 'does not create a default stock item' do
          new_variant
          expect(new_variant.reload.stock_items.count).to eq(0)
        end
      end

      context 'existing variant' do
        let(:variant) { create(:variant, product: product, track_inventory: true) }

        # clear out previous stock items
        before do
          variant.stock_items.delete_all
        end

        it 'creates a default stock item' do
          expect { variant.update!(track_inventory: false) }.to change(variant.stock_items, :count).by(1)
        end
      end
    end
  end

  describe 'after_update_commit :handle_track_inventory_change' do
    let!(:product) { create(:product, stores: [store]) }

    context 'when not tracking inventory' do
      subject { variant.update!(track_inventory: false) }

      let!(:variant) { create(:variant, product: product, track_inventory: true) }
      let!(:stock_item) { create(:stock_item, variant: variant, count_on_hand: 100) }

      it 'updates stock item count on hand to 0' do
        expect { subject }.to change { stock_item.reload.count_on_hand }.from(110).to(0)
      end
    end

    context 'when tracking inventory' do
      subject { variant.update!(track_inventory: true) }

      let!(:variant) { create(:variant, product: product, track_inventory: false) }
      let!(:stock_item) { create(:stock_item, variant: variant, count_on_hand: 100) }

      it 'keeps stock items' do
        expect { subject }.not_to change(variant.stock_items, :count)
      end
    end
  end

  describe 'after_commit :remove_prices_from_master_variant' do
    let(:variant) { build(:variant, product: product) }
    let(:product) { create(:product, stores: [store]) }

    let(:master) { product.master }

    it 'removes prices from master when variant with price is created' do
      expect { variant.save! }.to change(product.master.prices, :count).from(1).to(0)
    end
  end

  describe 'after_commit :remove_stock_items_from_master_variant' do
    let(:variant) { build(:variant, product: product) }
    let(:product) { create(:product, stores: [store]) }

    let(:master) { product.master }

    before do
      master.stock_items << create(:stock_item, variant: master)
      expect(master.stock_items.reload.count).to be >= 1
    end

    it 'removes stock items from master when variant is created' do
      variant.save!
      expect(product.master.stock_items.reload.count).to eq(0)
    end
  end

  describe 'scope' do
    describe '.eligible' do
      context 'when only master variants' do
        let!(:product_1) { create(:product, stores: [store]) }
        let!(:product_2) { create(:product, stores: [store]) }

        it 'returns all of them' do
          expect(Spree::Variant.eligible).to include(product_1.master)
          expect(Spree::Variant.eligible).to include(product_2.master)
        end
      end

      context 'when product has more than 1 variant' do
        let!(:product) { create(:product, stores: [store]) }
        let!(:variant) { create(:variant, product: product) }

        it 'filters master variant out' do
          expect(Spree::Variant.eligible).to include(variant)
          expect(Spree::Variant.eligible).not_to include(product.master)
        end
      end
    end

    describe '.not_discontinued' do
      context 'when discontinued' do
        let!(:discontinued_variant) { create(:variant, discontinue_on: Time.current - 1.day) }

        it { expect(Spree::Variant.not_discontinued).not_to include(discontinued_variant) }
      end

      context 'when not discontinued' do
        let!(:variant_2) { create(:variant, discontinue_on: Time.current + 1.day) }

        it { expect(Spree::Variant.not_discontinued).to include(variant_2) }
      end

      context 'when discontinue_on not present' do
        let!(:variant_2) { create(:variant, discontinue_on: nil) }

        it { expect(Spree::Variant.not_discontinued).to include(variant_2) }
      end
    end

    describe '.not_deleted' do
      context 'when deleted' do
        let!(:deleted_variant) { create(:variant, deleted_at: Time.current) }

        it { expect(Spree::Variant.not_deleted).not_to include(deleted_variant) }
      end

      context 'when not deleted' do
        let!(:variant_2) { create(:variant, deleted_at: nil) }

        it { expect(Spree::Variant.not_deleted).to include(variant_2) }
      end
    end

    describe '.for_currency_and_available_price_amount' do
      let(:currency) { 'EUR' }

      context 'when price with currency present' do
        context 'when price has amount' do
          let!(:price_1) { create(:price, currency: currency, variant: variant, amount: 10) }

          it { expect(Spree::Variant.for_currency_and_available_price_amount(currency)).to include(variant) }
        end

        context 'when price do not have amount' do
          before do
            allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
          end

          let!(:price_1) { create(:price, currency: currency, variant: variant, amount: nil) }

          it { expect(Spree::Variant.for_currency_and_available_price_amount(currency)).not_to include(variant) }
        end
      end

      context 'when price with currency not present' do
        let!(:unavailable_currency) { 'INR' }

        context 'when price has amount' do
          let!(:price_1) { create(:price, currency: unavailable_currency, variant: variant, amount: 10) }

          it { expect(Spree::Variant.for_currency_and_available_price_amount(currency)).not_to include(variant) }
        end

        context 'when price do not have amount' do
          before do
            allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
          end

          let!(:price_1) { create(:price, currency: unavailable_currency, variant: variant, amount: nil) }

          it { expect(Spree::Variant.for_currency_and_available_price_amount(currency)).not_to include(variant) }
        end
      end

      context 'when currency parameter is nil' do
        let!(:price_1) { create(:price, currency: currency, variant: variant, amount: 10) }

        before { Spree::Config[:currency] = currency }

        it { expect(Spree::Variant.for_currency_and_available_price_amount).to include(variant) }
      end
    end

    describe '.active' do
      let!(:variants) { [variant] }
      let!(:currency) { 'EUR' }

      before do
        allow(Spree::Variant).to receive(:not_discontinued).and_return(variants)
        allow(variants).to receive(:not_deleted).and_return(variants)
        allow(variants).to receive(:for_currency_and_available_price_amount).with(currency).and_return(variants)
      end

      it 'finds not_discontinued variants' do
        expect(Spree::Variant).to receive(:not_discontinued).and_return(variants)
        Spree::Variant.active(currency)
      end

      it 'finds not_deleted variants' do
        expect(variants).to receive(:not_deleted).and_return(variants)
        Spree::Variant.active(currency)
      end

      it 'finds variants for_currency_and_available_price_amount' do
        expect(variants).to receive(:for_currency_and_available_price_amount).with(currency).and_return(variants)
        Spree::Variant.active(currency)
      end

      it { expect(Spree::Variant.active(currency)).to eq(variants) }
    end
  end

  context 'product has other variants' do
    describe 'option value accessors' do
      before do
        @multi_variant = FactoryBot.create :variant, product: variant.product
        variant.product.reload
      end

      let(:multi_variant) { @multi_variant }

      it 'sets option value' do
        expect(multi_variant.option_value('media_type')).to be_nil

        multi_variant.set_option_value('media_type', 'DVD')
        expect(multi_variant.option_value('media_type')).to eql 'DVD'

        multi_variant.set_option_value('media_type', 'CD')
        expect(multi_variant.option_value('media_type')).to eql 'CD'
      end

      it 'does not duplicate associated option values when set multiple times' do
        multi_variant.set_option_value('media_type', 'CD')

        expect do
          multi_variant.set_option_value('media_type', 'DVD')
        end.not_to change(multi_variant.option_values, :count)

        expect do
          multi_variant.set_option_value('coolness_type', 'awesome')
        end.to change(multi_variant.option_values, :count).by(1)
      end
    end

    context 'product has other variants' do
      describe 'option value accessors' do
        before do
          @multi_variant = create(:variant, product: variant.product)
          variant.product.reload
        end

        let(:multi_variant) { @multi_variant }

        it 'sets option value' do
          expect(multi_variant.option_value('media_type')).to be_nil

          multi_variant.set_option_value('media_type', 'DVD')
          expect(multi_variant.option_value('media_type')).to eql 'DVD'

          multi_variant.set_option_value('media_type', 'CD')
          expect(multi_variant.option_value('media_type')).to eql 'CD'
        end

        it 'does not duplicate associated option values when set multiple times' do
          multi_variant.set_option_value('media_type', 'CD')

          expect do
            multi_variant.set_option_value('media_type ', ' DVD ')
            multi_variant.set_option_value('Media_Type  ', ' dvd ')
          end.not_to change(multi_variant.option_values, :count)

          expect do
            multi_variant.set_option_value('coolness_type', 'awesome')
          end.to change(multi_variant.option_values, :count).by(1)
        end
      end
    end
  end

  describe '#cost_price=' do
    it 'uses LocalizedNumber.parse' do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.cost_price = '1,599.99'
    end
  end

  describe '#in_stock_or_backorderable?' do
    subject { variant.in_stock_or_backorderable? }

    let!(:variant) { create(:variant) }

    context 'when variant has no stock items' do
      before { Spree::StockItem.delete_all }

      it { expect(subject).to eq(false) }
    end

    context 'when variant has stock items' do
      let!(:variant2) { create(:variant) }

      before { Spree::StockItem.update_all(backorderable: false) }

      context 'when variant stock items count_on_hand > 0' do
        before { variant.stock_items.first.set_count_on_hand(1) }

        it { expect(subject).to eq(true) }
      end

      context 'when variant stock items count_on_hand <= 0' do
        before { variant.stock_items.first.set_count_on_hand(0) }

        it { expect(subject).to eq(false) }

        context 'when variant track_inventory = false' do
          before { variant.update(track_inventory: false) }

          it { expect(subject).to eq(true) }
        end

        context 'when variant track_inventory = true' do
          it { expect(variant.in_stock_or_backorderable?).to eq(false) }

          context 'with some variant stock item having backorderable = true' do
            before { variant.stock_items.first.update(backorderable: true) }

            it { expect(subject).to eq(true) }
          end
        end
      end
    end
  end

  describe '#price=' do
    it 'uses LocalizedNumber.parse' do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.price = '1,599.99'
    end
  end

  describe '#weight=' do
    it 'uses LocalizedNumber.parse' do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.weight = '1,599.99'
    end
  end

  describe '#currency' do
    it 'returns the globally configured currency' do
      expect(variant.currency).to eql 'USD'
    end
  end

  describe '#display_amount' do
    it 'returns a Spree::Money' do
      variant.price = 21.22
      expect(variant.display_amount.to_s).to eql '$21.22'
    end
  end

  describe '#cost_currency' do
    context 'when cost currency is nil' do
      before { variant.cost_currency = nil }

      it 'populates cost currency with the default value on save' do
        variant.save!
        expect(variant.cost_currency).to eql 'USD'
      end
    end
  end

  describe '#price_in' do
    subject { variant.price_in(currency).display_amount }

    before do
      create(:price, variant: variant, currency: 'EUR', amount: 33.33)
    end

    context 'when currency is not specified' do
      let(:currency) { nil }

      it 'returns 0' do
        expect(subject.to_s).to eql '$0.00'
      end
    end

    context 'when currency is EUR' do
      let(:currency) { 'EUR' }

      it 'returns the value in the EUR' do
        expect(subject.to_s).to eql '€33.33'
      end
    end

    context 'when currency is USD' do
      let(:currency) { 'USD' }

      it 'returns the value in the USD' do
        expect(subject.to_s).to eql '$19.99'
      end
    end

    context 'when there is no price with present amount in given currency' do
      let(:currency) { 'GBP' }

      before do
        variant.prices.create(currency: 'GBP', amount: nil)
      end

      it 'returns 0' do
        expect(subject.to_s).to eql '£0.00'
      end
    end

    context 'when price exists in a price list' do
      let(:currency) { 'GBP' }
      let(:price_list) { create(:price_list) }

      before do
        create(:price, variant: variant, currency: 'GBP', amount: 50.00, price_list: price_list)
      end

      it 'does not return price list price' do
        expect(subject.to_s).to eql '£0.00'
      end

      context 'when base price also exists' do
        before do
          create(:price, variant: variant, currency: 'GBP', amount: 25.00)
        end

        it 'returns the base price, not the price list price' do
          expect(subject.to_s).to eql '£25.00'
        end
      end
    end
  end

  describe '#set_price' do
    let(:currency) { 'GBP' }

    it 'creates a base price for the currency' do
      variant.set_price(currency, 25.00)

      price = variant.prices.find_by(currency: currency)
      expect(price.amount).to eq(25.00)
      expect(price.price_list_id).to be_nil
    end

    it 'updates existing base price' do
      create(:price, variant: variant, currency: currency, amount: 10.00)

      variant.set_price(currency, 30.00)

      expect(variant.prices.where(currency: currency).count).to eq(1)
      expect(variant.prices.find_by(currency: currency).amount).to eq(30.00)
    end

    it 'does not update price list price' do
      price_list = create(:price_list)
      price_list_price = create(:price, variant: variant, currency: currency, amount: 50.00, price_list: price_list)

      variant.set_price(currency, 25.00)

      expect(variant.prices.where(currency: currency).count).to eq(2)
      expect(price_list_price.reload.amount).to eq(50.00)
      expect(variant.prices.base_prices.find_by(currency: currency).amount).to eq(25.00)
    end

    it 'sets compare_at_amount when provided' do
      variant.set_price(currency, 25.00, 35.00)

      price = variant.prices.find_by(currency: currency)
      expect(price.amount).to eq(25.00)
      expect(price.compare_at_amount).to eq(35.00)
    end
  end

  describe '#on_sale?' do
    subject { variant.on_sale?(currency) }

    let!(:eur_price) { create(:price, variant: variant, currency: 'EUR', amount: 100.00, compare_at_amount: eur_compare_at_amount) }
    let!(:gbp_price) { create(:price, variant: variant, currency: 'GBP', amount: 100.00, compare_at_amount: gbp_compare_at_amount) }
    let(:usd_compare_at_amount) { nil }
    let(:eur_compare_at_amount) { nil }
    let(:gbp_compare_at_amount) { nil }

    before do
      variant.prices.where(currency: 'USD').take.update(amount: 100.00, compare_at_amount: usd_compare_at_amount)
    end

    context 'when existing currency is passed' do
      let(:currency) { 'GBP' }
      let(:gbp_compare_at_amount) { 200.00 }

      it 'checks if variant is discounted in that currency' do
        expect(subject).to be true
      end

      context 'when variant is discounted' do
        let(:currency) { 'EUR' }
        let(:eur_compare_at_amount) { 200.00 }
        let(:gbp_compare_at_amount) { nil }

        it 'returns true' do
          expect(subject).to be true
        end
      end

      context 'when variant is not discounted' do
        let(:currency) { 'EUR' }

        it 'returns false' do
          expect(subject).to be false
        end
      end
    end

    context 'when passed currency does not exist' do
      let(:currency) { 'NON_EXISTING_CURRENCY' }
      let(:usd_compare_at_amount) { 200.00 }
      let(:eur_compare_at_amount) { 200.00 }
      let(:gbp_compare_at_amount) { 200.00 }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '.amount_in' do
    subject { variant.amount_in(currency) }

    before do
      variant.prices << create(:price, variant: variant, currency: 'EUR', amount: 33.33)
    end

    context 'when currency is not specified' do
      let(:currency) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when currency is EUR' do
      let(:currency) { 'EUR' }

      it 'returns the value in the EUR' do
        expect(subject).to eq(33.33)
      end
    end

    context 'when currency is USD' do
      let(:currency) { 'USD' }

      it 'returns the value in the USD' do
        expect(subject).to eq(19.99)
      end
    end
  end

  describe '#options' do
    let(:product) { create(:product, option_types: [option_type, option_type2]) }
    let(:variant) { create(:variant, product: product, option_values: [option_value, option_value2]) }
    let!(:option_type2) { create(:option_type, name: 'material') }
    let!(:option_type) { Spree::OptionType.find_by(name: 'size') || create(:option_type, name: 'size') }
    let(:option_value) { create(:option_value, name: 'medium', presentation: 'M', option_type: option_type) }
    let(:option_value2) { create(:option_value, name: 'wool', presentation: 'Wool', option_type: option_type2) }

    it 'returns an array of hashes with option type name, value, and presentation orderd by option type position' do
      expect(variant.options).to eq([
                                      {
                                        name: 'size',
                                        value: 'medium',
                                        presentation: 'M'
                                      },
                                      {
                                        name: 'material',
                                        value: 'wool',
                                        presentation: 'Wool'
                                      }
                                    ])
    end
  end

  describe '#options_text' do
    subject(:options_text) { variant.options_text }

    context 'when the variant has no option values' do
      let(:variant) { build(:variant, option_values: []) }

      it 'returns an empty string' do
        expect(options_text).to eql ''
      end
    end

    context 'when the variant has option values' do
      let(:variant) { build(:variant, option_values: [create(:option_value, name: 'Foo', presentation: 'Foo', option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type'))]) }

      it 'returns the options text of the variant' do
        expect(options_text).to eql 'Foo Type: Foo'
      end
    end
  end

  describe 'exchange_name' do
    let!(:variant) { build(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value,                                                      name: 'Foo',
                                                                                                          presentation: 'Foo',
                                                                                                          option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type'))
      variant.save
    end

    context 'master variant' do
      it 'returns name' do
        expect(master.exchange_name).to eql master.name
      end
    end

    context 'variant' do
      it 'returns options text' do
        expect(variant.exchange_name).to eql 'Foo Type: Foo'
      end
    end
  end

  describe 'exchange_name' do
    let!(:variant) { build(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value,                                                      name: 'Foo',
                                                                                                          presentation: 'Foo',
                                                                                                          option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type'))
      variant.save
    end

    context 'master variant' do
      it 'returns name' do
        expect(master.exchange_name).to eql master.name
      end
    end

    context 'variant' do
      it 'returns options text' do
        expect(variant.exchange_name).to eql 'Foo Type: Foo'
      end
    end
  end

  describe 'descriptive_name' do
    let!(:variant) { build(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value,                                                      name: 'Foo',
                                                                                                          presentation: 'Foo',
                                                                                                          option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type'))
      variant.save
    end

    context 'master variant' do
      it 'returns name with Master identifier' do
        expect(master.descriptive_name).to eql master.name + ' - Master'
      end
    end

    context 'variant' do
      it 'returns options text with name' do
        expect(variant.descriptive_name).to eql variant.name + ' - Foo Type: Foo'
      end
    end
  end

  # Regression test for #2744
  describe 'set_position' do
    it 'sets variant position after creation' do
      variant = create(:variant)
      expect(variant.position).not_to be_nil
    end
  end

  describe '#in_stock?' do
    before do
      Spree::Config.track_inventory_levels = true
    end

    context 'when stock_items are not backorderable' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
      end

      context 'when stock_items in stock' do
        before do
          variant.stock_items.first.update_column(:count_on_hand, 10)
        end

        it 'returns true if stock_items in stock' do
          expect(variant.in_stock?).to be true
        end
      end

      context 'when stock_items out of stock' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
          allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
        end

        it 'return false if stock_items out of stock' do
          expect(variant.in_stock?).to be false
        end
      end
    end

    describe '#can_supply?' do
      before { variant }

      it 'calls out to quantifier' do
        expect(Spree::Stock::Quantifier).to receive(:new).and_return(quantifier = double)
        expect(quantifier).to receive(:can_supply?).with(10)
        variant.can_supply?(10)
      end
    end

    context 'when stock_items are backorderable' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: true)
      end

      context 'when stock_items out of stock' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
        end

        it 'in_stock? returns false' do
          expect(variant.in_stock?).to be false
        end

        it 'can_supply? return true' do
          expect(variant.can_supply?).to be true
        end
      end
    end
  end

  describe '#is_backorderable' do
    subject { variant.is_backorderable? }

    let(:variant) { build(:variant) }

    it 'invokes Spree::Stock::Quantifier' do
      expect_any_instance_of(Spree::Stock::Quantifier).to receive(:backorderable?).and_return(true)
      subject
    end
  end

  describe '#purchasable?' do
    context 'when stock_items are not backorderable' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
      end

      context 'when stock_items in stock' do
        before do
          variant.stock_items.first.update_column(:count_on_hand, 10)
        end

        it 'returns true if stock_items in stock' do
          expect(variant.purchasable?).to be true
        end
      end

      context 'when stock_items out of stock' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
        end

        it 'return false if stock_items out of stock' do
          expect(variant.purchasable?).to be false
        end
      end
    end

    context 'when stock_items are out of stock' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
      end

      context 'when stock item are backorderable' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: true)
        end

        it 'returns true if stock_items are backorderable' do
          expect(variant.purchasable?).to be true
        end
      end

      context 'when stock_items are not backorderable' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
        end

        it 'return false if stock_items are not backorderable' do
          expect(variant.purchasable?).to be false
        end
      end
    end
  end

  describe '#total_on_hand' do
    it 'is infinite if track_inventory_levels is false' do
      Spree::Config[:track_inventory_levels] = false
      expect(build(:variant).total_on_hand).to eql(Float::INFINITY)
    end

    it 'matches quantifier total_on_hand' do
      variant = build(:variant)
      expect(variant.total_on_hand).to eq(Spree::Stock::Quantifier.new(variant).total_on_hand)
    end
  end

  describe '#tax_category' do
    context 'when tax_category is nil' do
      let(:product) { build(:product) }
      let(:variant) { build(:variant, product: product, tax_category_id: nil) }

      it 'returns the parent products tax_category' do
        expect(variant.tax_category).to eq(product.tax_category)
      end
    end

    context 'when tax_category is set' do
      let(:tax_category) { create(:tax_category) }
      let(:variant) { build(:variant, tax_category: tax_category) }

      it 'returns the tax_category set on itself' do
        expect(variant.tax_category).to eq(tax_category)
      end
    end

    context 'when tax category is deleted' do
      let(:tax_category) { create(:tax_category) }
      let(:variant) { build(:variant, tax_category: tax_category) }

      before do
        tax_category.destroy
      end

      it 'returns the parent products tax_category' do
        expect(variant.tax_category).to eq(variant.product.tax_category)
      end
    end

    context 'when tax category is deleted also in product' do
      let(:tax_category) { create(:tax_category) }
      let!(:product) { create(:product, tax_category: tax_category) }
      let!(:variant) { create(:variant, product: product, tax_category: tax_category) }

      context 'with default tax category' do
        let!(:default_tax_category) { create(:tax_category, is_default: true) }

        before do
          tax_category.destroy
          product.reload
          variant.reload
        end

        it 'returns the default tax category' do
          expect(variant.tax_category).to eq(default_tax_category)
        end
      end

      context 'without default tax category' do
        before do
          tax_category.destroy
          product.reload
          variant.reload
        end

        it 'returns nil' do
          expect(variant.reload.tax_category).to eq(nil)
        end
      end
    end
  end

  describe 'touching' do
    it 'updates a product' do
      variant.product.update_column(:updated_at, 1.day.ago)
      variant.touch
      expect(variant.product.reload.updated_at).to be_within(3.seconds).of(Time.current)
    end

    it 'clears the in_stock cache key' do
      expect(Rails.cache).to receive(:delete).with(variant.send(:in_stock_cache_key))
      variant.touch
    end

    context 'when unlinking an option value' do
      let(:option_value) { create(:option_value) }

      before do
        variant.option_values << option_value
        variant.save!
      end

      it 'touches variant' do
        expect(variant).to receive(:touch)

        option_values = variant.option_values - [option_value]
        variant.update(option_values: option_values)
      end
    end
  end

  describe '#should_track_inventory?' do
    it 'does not track inventory when global setting is off' do
      Spree::Config[:track_inventory_levels] = false

      expect(build(:variant).should_track_inventory?).to eq(false)
    end

    it 'does not track inventory when variant is turned off' do
      Spree::Config[:track_inventory_levels] = true

      expect(build(:on_demand_variant).should_track_inventory?).to eq(false)
    end

    it 'tracks inventory when global and variant are on' do
      Spree::Config[:track_inventory_levels] = true

      expect(build(:variant).should_track_inventory?).to eq(true)
    end
  end

  describe 'deleted_at scope' do
    before { variant.destroy && variant.reload }

    it 'has a price if deleted' do
      variant.price = 10
      expect(variant.price).to eq(10)
    end
  end

  describe 'stock movements' do
    let!(:movement) { create(:stock_movement, stock_item: variant.stock_items.first) }

    it 'builds out collection just fine through stock items' do
      expect(variant.stock_movements.to_a).not_to be_empty
    end
  end

  describe 'in_stock scope' do
    it 'returns all in stock variants' do
      in_stock_variant = create(:variant)
      create(:variant) # out_of_stock_variant

      in_stock_variant.stock_items.first.update_column(:count_on_hand, 10)

      expect(Spree::Variant.in_stock).to eq [in_stock_variant]
    end
  end

  describe '#volume' do
    let(:variant_zero_width) { create(:variant, width: 0) }
    let(:variant) { create(:variant) }

    it 'is zero if any dimension parameter is zero' do
      expect(variant_zero_width.volume).to eq 0
    end

    it 'return the volume if the dimension parameters are different of zero' do
      volume_expected = variant.width * variant.depth * variant.height
      expect(variant.volume).to eq volume_expected
    end
  end

  describe '#dimension' do
    let(:variant) { create(:variant) }

    it 'return the dimension if the dimension parameters are different of zero' do
      dimension_expected = variant.width + variant.depth + variant.height
      expect(variant.dimension).to eq dimension_expected
    end
  end

  describe '#discontinue!' do
    let(:variant) { create(:variant) }

    it 'sets the discontinued' do
      variant.discontinue!
      variant.reload
      expect(variant.discontinued?).to be(true)
    end

    it 'changes updated_at' do
      Timecop.scale(1000) do
        expect { variant.discontinue! }.to change(variant.reload, :updated_at)
      end
    end
  end

  describe '#discontinued?' do
    let(:variant_live) { build(:variant) }
    let(:variant_discontinued) { build(:variant, discontinue_on: Time.now - 1.day) }

    it 'is false' do
      expect(variant_live.discontinued?).to be(false)
    end

    it 'is true' do
      expect(variant_discontinued.discontinued?).to be(true)
    end
  end

  describe '#available?' do
    let(:variant) { create(:variant) }

    context 'when discontinued' do
      before do
        variant.discontinue_on = Time.current - 1.day
      end

      context 'when product is available' do
        before do
          allow(variant.product).to receive(:available?).and_return(true)
        end

        it { expect(variant.available?).to be(false) }
      end

      context 'when product is not available' do
        before do
          allow(variant.product).to receive(:available?).and_return(false)
        end

        it { expect(variant.available?).to be(false) }
      end
    end

    context 'when not discontinued' do
      before do
        variant.discontinue_on = Time.current + 1.day
      end

      context 'when product is available' do
        before do
          allow(variant.product).to receive(:available?).and_return(true)
        end

        it { expect(variant.available?).to be(true) }
      end

      context 'when product is not available' do
        before do
          allow(variant.product).to receive(:available?).and_return(false)
        end

        it { expect(variant.available?).to be(false) }
      end
    end
  end

  describe 'validate :check_price' do
    subject { variant.save }

    let(:currency) { store.default_currency }

    context 'when variant has a default price' do
      let(:variant) { build(:variant, product: product, default_price: default_price) }

      let(:product) { create(:product, master: master) }
      let(:master) { create(:master_variant, price: 11.11, currency: currency) }

      let(:default_price) { build(:price, amount: 12.34, currency: currency) }

      it 'keeps the default price' do
        expect(subject).to be(true)
        expect(variant.price_in(currency).amount).to eq(12.34)
      end

      context 'when the default price is invalid' do
        let(:default_price) { build(:price, amount: nil, currency: currency) }

        it 'infers price from the default variant' do
          expect(subject).to be(true)
          expect(variant.price_in(currency).amount).to eq(11.11)
        end

        context 'when there is no default variant' do
          let(:product) { nil }

          it 'adds an error' do
            expect(subject).to be(false)
            expect(variant.errors[:base]).to contain_exactly(
              I18n.t('activerecord.errors.models.spree/variant.attributes.base.no_master_variant_found_to_infer_price')
            )
          end
        end
      end
    end

    context 'when variant has no default price' do
      let(:variant) { build(:variant, :with_no_price, product: product) }

      let(:product) { create(:product, master: master) }
      let(:master) { create(:master_variant, price: 11.11, currency: currency) }

      it 'infers price from the default variant' do
        expect(subject).to be(true)
        expect(variant.price_in(currency).amount).to eq(11.11)
      end

      context 'when there is no default variant' do
        let(:product) { nil }

        it 'adds an error' do
          expect(subject).to be(false)
          expect(variant.errors[:base]).to contain_exactly(
            I18n.t('activerecord.errors.models.spree/variant.attributes.base.no_master_variant_found_to_infer_price')
          )
        end
      end
    end

    context 'when variant has prices' do
      let(:variant) { build(:variant, :with_no_price, prices: [price_1, price_2]) }

      let(:price_1) { build(:price, amount: 10, currency: 'PLN') }
      let(:price_2) { build(:price, amount: 11, currency: 'GBP') }

      it 'keeps the prices' do
        expect(subject).to be(true)

        expect(variant.prices.count).to eq(2)
        expect(variant.price_in('PLN').amount).to eq(10)
        expect(variant.price_in('GBP').amount).to eq(11)
      end
    end

    context 'when variant price '
  end

  describe '#created_at' do
    it 'creates variant with created_at timestamp' do
      expect(variant.created_at).not_to be_nil
    end
  end

  describe '#updated_at' do
    it 'creates variant with updated_at timestamp' do
      expect(variant.updated_at).not_to be_nil
    end
  end

  describe '#backordered?' do
    let!(:variant) { create(:variant) }

    it 'returns true when out of stock and backorderable' do
      expect(variant.backordered?).to eq(true)
    end

    it 'returns false when out of stock and not backorderable' do
      variant.stock_items.first.update(backorderable: false)
      expect(variant.backordered?).to eq(false)
    end

    it 'returns false when there is available item in stock' do
      variant.stock_items.first.update(count_on_hand: 10)
      expect(variant.backordered?).to eq(false)
    end
  end

  describe '#ensure_not_in_complete_orders' do
    let!(:order) { create(:completed_order_with_totals) }
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    it 'adds error on variant destroy' do
      expect(variant.destroy).to eq false
      expect(variant.errors[:base]).to include I18n.t('activerecord.errors.models.spree/variant.attributes.base.cannot_destroy_if_attached_to_line_items')
    end
  end

  describe '#remove_line_items_from_incomplete_orders' do
    let!(:order) { create(:order) }
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }
    let!(:line_item_2) { create(:line_item, order: order, variant: variant, quantity: 3) }

    before do
      variant.update(track_inventory: false)
    end

    it 'schedules RemoveFromIncompleteOrdersJob' do
      expect(Spree::Variants::RemoveFromIncompleteOrdersJob).to receive(:perform_later).with(variant)
      variant.destroy
    end

    it 'deletes the line items from the order' do
      perform_enqueued_jobs { variant.destroy }
      expect(order.line_items.reload).to be_empty
      expect(order.total).to eq(0)
    end
  end

  describe '#default_image' do
    let(:variant) { create(:variant) }
    let!(:image) { create(:image, position: 1, viewable: variant) }

    it 'returns the first image for the variant' do
      expect(variant.default_image).to eq(image)
    end
  end

  describe '#secondary_image' do
    let(:variant) { create(:variant) }
    let!(:image) { create(:image, position: 1, viewable: variant) }
    let!(:image2) { create(:image, position: 2, viewable: variant) }

    it 'returns the second image for the variant' do
      expect(variant.secondary_image).to eq(image2)
    end
  end

  describe '#additional_images' do
    let(:variant) { create(:variant) }
    let!(:image) { create(:image, position: 1, viewable: variant) }
    let!(:image2) { create(:image, position: 2, viewable: variant) }
    let!(:image3) { create(:image, position: 3, viewable: variant) }

    it 'returns the additional images for the variant' do
      expect(variant.additional_images).to eq([image2, image3])
    end
  end
end
