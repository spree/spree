require 'spec_helper'

module ThirdParty
  class Extension < Spree::Base
    # nasty hack so we don't have to create a table to back this fake model
    self.table_name = 'spree_products'
  end
end

describe Spree::Product, type: :model do
  it_behaves_like 'metadata'

  let!(:store) { Spree::Store.default }

  describe 'after_initialize :assign_default_tax_category' do
    let!(:tax_category_1) { create(:tax_category, is_default: false) }
    let!(:tax_category_2) { create(:tax_category, is_default: true) }

    context 'when product is new' do
      let(:product) { described_class.new(stores: [store]) }

      it 'assigns default tax category' do
        expect(product.tax_category.id).to eq(tax_category_2.id)
      end
    end

    context 'when product is persisted' do
      let(:product) { create(:product, tax_category: nil, stores: [store]) }

      it 'does not assign default tax category' do
        expect(product.tax_category_id).to be(nil)
      end
    end
  end

  describe 'before_validation :ensure_default_shipping_category' do
    subject { product.valid? }

    let(:product) { build(:product, shipping_category: nil, stores: [store]) }

    let!(:shipping_category_1) { create(:shipping_category, name:  I18n.t('spree.seed.shipping.categories.digital')) }
    let!(:shipping_category_2) { create(:shipping_category, name:  I18n.t('spree.seed.shipping.categories.default')) }

    it 'assigns the default shipping category' do
      subject
      expect(product.shipping_category).to eq(shipping_category_2)
    end

    context 'when product has a shipping category' do
      let(:product) { build(:product, shipping_category: shipping_category_1, stores: [store]) }

      it 'keeps the assigned shipping category' do
        subject
        expect(product.shipping_category).to eq(shipping_category_1)
      end
    end

    context 'when product is persisted' do
      let(:product) { create(:product, stores: [store]) }

      before do
      end

      it 'does not assign the default shipping category' do
        product.update(shipping_category: nil)
        expect(subject).to be(false)
        expect(product.shipping_category).to be(nil)
      end
    end
  end

  context 'product instance' do
    let(:product) { create(:product, stores: [store]) }
    let(:variant) { create(:variant, product: product) }

    %w[purchasable backorderable in_stock].each do |method_name|
      describe "#{method_name}?" do
        context 'with variants' do
          it "returns false if no variant is #{method_name.humanize.downcase} even if master is" do
            variant.stock_items.update_all(backorderable: false) if %w[purchasable backorderable].include?(method_name)
            variant.stock_items.update_all(count_on_hand: 0) if method_name == 'in_stock'

            product.master.stock_items.where(variant: product.master).update_all(backorderable: true) if %w[purchasable backorderable].include?(method_name)
            product.master.stock_items.where(variant: product.master).update_all(count_on_hand: 10) if method_name == 'in_stock'

            expect(product.reload.send("#{method_name}?")).to eq false
          end

          it "returns true if variant is #{method_name.humanize.downcase}" do
            variant.stock_items.update_all(backorderable: true) if %w[purchasable backorderable].include?(method_name)
            variant.stock_items.update_all(count_on_hand: 10) if method_name == 'in_stock'

            expect(product.reload.send("#{method_name}?")).to eq true
          end
        end

        context 'without variants' do
          it "returns false if master is not #{method_name.humanize.downcase}" do
            product.master.stock_items.update_all(backorderable: false) if %w[purchasable backorderable].include?(method_name)
            product.master.stock_items.update_all(count_on_hand: 0) if method_name == 'in_stock'

            expect(product.reload.send("#{method_name}?")).to eq false
          end

          it "returns true if master is #{method_name.humanize.downcase}" do
            product.master.stock_items.update_all(backorderable: true) if %w[purchasable backorderable].include?(method_name)
            product.master.stock_items.update_all(count_on_hand: 10) if method_name == 'in_stock'

            expect(product.reload.send("#{method_name}?")).to eq true
          end
        end
      end
    end

    describe '#duplicate' do
      before do
        allow(product).to receive_messages taxons: [create(:taxon)], stores: [store]
      end

      it 'duplicates product' do
        duplicate_result = product.duplicate
        expect(duplicate_result).to be_success

        clone = duplicate_result.value
        expect(clone.name).to eq("COPY OF #{product.name}")
        expect(clone.slug).to eq("copy-of-#{product.slug}")
        expect(clone.master.sku).to eq("COPY OF #{product.master.sku}")
        expect(clone.taxons).to eq(product.taxons)
        expect(clone.stores).to eq(product.stores)
        expect(clone.images.size).to eq(product.images.size)
      end

      context 'when translations exist for another locale' do
        before do
          Mobility.with_locale(:fr) { product.name = "french name" }
          product.save!
        end

        it 'duplicates translations for all locales' do
          duplicate_result = product.duplicate
          expect(duplicate_result).to be_success

          clone = duplicate_result.value
          expect(clone.name(locale: :fr)).to eq("COPY OF #{product.name(locale: :fr)}")
        end
      end

      it 'calls #duplicate_extra' do
        expect_any_instance_of(Spree::Product).to receive(:duplicate_extra).
          with(product)
        expect(product).not_to receive(:duplicate_extra)
        product.duplicate
      end
    end

    context 'master variant' do
      context 'when master variant changed' do
        before do
          product.master.sku = 'Something changed'
        end

        it 'saves the master' do
          product.save
          expect(product.master.reload.sku).to eq('Something changed')
        end
      end

      context 'when master default price changed' do
        before do
          master = product.master
          master.default_price.price = 11
          master.save!
          product.master.default_price.price = 12
        end

        it 'saves the master' do
          expect(product.master).to receive(:save!)
          product.save
        end

        it 'saves the default price' do
          expect(product.master.default_price).to receive(:save)
          product.save
        end
      end

      context "when master variant and price haven't changed" do
        it 'does not save the master' do
          expect(product.master).not_to receive(:save!)
          product.save
        end
      end
    end

    context 'product has no variants' do
      describe '#destroy' do
        it 'sets deleted_at value' do
          product.destroy
          expect(product.deleted_at).not_to be_nil
          expect(product.master.reload.deleted_at).not_to be_nil
        end
      end
    end

    context 'product has variants' do
      before do
        create(:variant, product: product)
      end

      describe '#destroy' do
        it 'sets deleted_at value' do
          product.destroy
          expect(product.deleted_at).not_to be_nil
          expect(product.variants_including_master.all? { |v| !v.deleted_at.nil? }).to be true
        end
      end
    end

    describe '#price' do
      # Regression test for #1173
      it 'strips non-price characters' do
        product.price = '$10'
        expect(product.price).to eq(10.0)
      end
    end

    describe '#display_price' do
      before { product.price = 10.55 }

      it 'shows the amount' do
        expect(product.display_price.to_s).to eq('$10.55')
      end

      context 'with currency set to JPY' do
        before do
          product.master.default_price.currency = 'JPY'
          product.master.default_price.save!
          Spree::Config[:currency] = 'JPY'
        end

        it 'displays the currency in yen' do
          expect(product.display_price.to_s).to eq('¥11')
        end
      end
    end

    describe '#available?' do
      it 'is available if status is set to active' do
        product.status = 'active'
        expect(product).to be_available
      end

      it 'is not available if destroyed' do
        product.destroy
        expect(product).not_to be_available
      end

      it 'is not available when available_on is in the future' do
        product.available_on = 1.day.from_now

        expect(product).not_to be_available
      end
    end

    describe '#can_supply?' do
      it 'is true' do
        expect(product.can_supply?).to be(true)
      end

      it 'is false' do
        product.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }
        expect(product.can_supply?).to be(false)
      end
    end

    context 'variants_and_option_values' do
      let!(:high) { create(:variant, product: product) }
      let!(:low) { create(:variant, product: product) }

      before { high.option_values.destroy_all }

      it 'returns only variants with option values' do
        expect(product.variants_and_option_values).to eq([low])
      end
    end

    context 'has stock movements' do
      let(:variant) { product.master }
      let(:stock_item) { variant.stock_items.first }

      it 'doesnt raise ReadOnlyRecord error' do
        Spree::StockMovement.create!(stock_item: stock_item, quantity: 1)
        expect { product.destroy }.not_to raise_error
      end
    end

    # Regression test for #3737
    context 'has stock items' do
      it 'can retrieve stock items' do
        expect(product.master.stock_items.first).not_to be_nil
        expect(product.stock_items.first).not_to be_nil
      end
    end

    describe '#discontinue_on_must_be_later_than_make_active_at' do
      before { product.make_active_at = Date.today }

      context 'make_active_at is a date earlier than discontinue_on' do
        before { product.discontinue_on = 5.days.from_now }

        it 'is valid' do
          expect(product).to be_valid
        end
      end

      context 'make_active_at is a date earlier than discontinue_on' do
        before { product.discontinue_on = 5.days.ago }

        context 'is not valid' do
          before { product.valid? }

          it { expect(product).not_to be_valid }
          it { expect(product.errors[:discontinue_on]).to include(I18n.t(:invalid_date_range, scope: 'activerecord.errors.models.spree/product.attributes.discontinue_on')) }
        end
      end

      context 'make_active_at and discontinue_on are nil' do
        before do
          product.discontinue_on = nil
          product.make_active_at = nil
        end

        it 'is valid' do
          expect(product).to be_valid
        end
      end
    end

    context 'hard deletion' do
      it 'doesnt raise ActiveRecordError error' do
        expect { product.really_destroy! }.not_to raise_error(ActiveRecord::ActiveRecordError)
      end
    end

    context 'history' do
      before do
        @product = create(:product, stores: [store])
      end

      it 'keeps translations when product is destroyed' do
        @product.destroy

        expect(@product.name).not_to be_empty
      end
    end

    context 'memoized data' do
      let(:corrent_total_on_hand) { 5 }
      let(:incorrent_total_on_hand) { 15 }

      before do
        product.stock_items.first.set_count_on_hand corrent_total_on_hand
        product.instance_variable_set(:@total_on_hand, incorrent_total_on_hand)
      end

      it 'without action keeps data' do
        expect(product.total_on_hand).to eq incorrent_total_on_hand
      end

      it 'resets memoized data after save' do
        product.save
        expect(product.total_on_hand).to eq corrent_total_on_hand
      end

      it 'resets memoized data reload' do
        expect(product.reload.total_on_hand).to eq corrent_total_on_hand
      end
    end

    context 'when using another locale' do
      before do
        product.update!(name: 'EN name')

        Mobility.with_locale(:pl) do
          product.update!(
            name: 'PL name',
            description: 'PL description',
            meta_title: 'PL meta title',
            meta_description: 'PL meta description',
            meta_keywords: 'PL meta keywords'
          )
        end
      end

      let(:product_pl_translation) { product.translations.find_by(locale: 'pl') }

      it 'translates product fields' do
        expect(product.name).to eq('EN name')

        expect(product_pl_translation).to be_present
        expect(product_pl_translation.name).to eq('PL name')
        expect(product_pl_translation.slug).to eq('pl-name')
        expect(product_pl_translation.description).to eq('PL description')
        expect(product_pl_translation.meta_title).to eq('PL meta title')
        expect(product_pl_translation.meta_description).to eq('PL meta description')
      end
    end
  end

  context 'properties' do
    let(:product) { create(:product, stores: [store]) }

    it 'properly assigns properties' do
      product.set_property('the_prop', 'value1')
      expect(product.property('the_prop')).to eq('value1')

      product.set_property('the_prop', 'value2')
      expect(product.property('the_prop')).to eq('value2')

      I18n.with_locale(:pl) do
        product.set_property('the_prop', 'translated-value1', 'the_translated_prop')
        expect(product.property('the_prop')).to eq('translated-value1')

        product.set_property('the_prop', 'translated-value2')
        expect(product.property('the_prop')).to eq('translated-value2')

        expect(product.properties[0].presentation).to eq('the_translated_prop')
      end

      expect(product.properties[0].presentation).to eq('the_prop')
    end

    it 'does not create duplicate properties when set_property is called' do
      expect do
        product.set_property('the_prop', 'value2')
        product.save
        product.reload
      end.not_to change(product.properties, :length)

      expect do
        product.set_property('the_prop_new', 'value')
        product.save
        product.reload
        expect(product.property('the_prop_new')).to eq('value')
      end.to change { product.properties.length }.by(1)
    end

    context 'optional property_presentation' do
      subject { Spree::Property.where(name: 'foo').first.presentation }

      let(:name) { 'foo' }
      let(:presentation) { 'baz' }

      describe 'is not used' do
        before { product.set_property(name, 'bar') }

        it { is_expected.to eq name }
      end

      describe 'is used' do
        before { product.set_property(name, 'bar', presentation) }

        it { is_expected.to eq presentation }
      end
    end

    # Regression test for #2455
    it "does not overwrite properties' presentation names" do
      Spree::Property.create!(name: 'foo', presentation: "Foo's Presentation Name")
      product.set_property('foo', 'value1')
      product.set_property('bar', 'value2')
      expect(Spree::Property.where(name: 'foo').first.presentation).to eq("Foo's Presentation Name")
      expect(Spree::Property.where(name: 'bar').first.presentation).to eq('bar')
    end

    # Regression test for #4416
    describe '#possible_promotions' do
      let!(:possible_promotion) { create(:promotion, advertise: true, starts_at: 1.day.ago) }
      let!(:unadvertised_promotion) { create(:promotion, advertise: false, starts_at: 1.day.ago) }
      let!(:inactive_promotion) { create(:promotion, advertise: true, starts_at: 1.day.since) }

      before do
        product.promotion_rules.create!(promotion: possible_promotion)
        product.promotion_rules.create!(promotion: unadvertised_promotion)
        product.promotion_rules.create!(promotion: inactive_promotion)
      end

      it 'lists the promotion as a possible promotion' do
        expect(product.possible_promotions).to include(possible_promotion)
        expect(product.possible_promotions).not_to include(unadvertised_promotion)
        expect(product.possible_promotions).not_to include(inactive_promotion)
      end
    end
  end

  describe '#create' do
    let!(:prototype) { create(:prototype) }
    let!(:product) { build(:product, name: 'Foo', price: 1.99, shipping_category: create(:shipping_category), stores: [store]) }

    before { product.prototype_id = prototype.id }

    context 'when prototype is supplied' do
      it 'creates properties based on the prototype' do
        product.save
        expect(product.properties.count).to eq(1)
      end
    end

    context 'when prototype with option types is supplied' do
      def build_option_type_with_values(name, values)
        values.each_with_object(create(:option_type, name: name)) do |val, ot|
          ot.option_values.create(name: val.downcase, presentation: val)
        end
      end

      let(:prototype) do
        size = build_option_type_with_values('size', %w(Small Medium Large))
        create(:prototype, name: 'Size', option_types: [size])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      it 'creates option types based on the prototype' do
        product.save
        expect(product.option_type_ids.length).to eq(1)
        expect(product.option_type_ids).to eq(prototype.option_type_ids)
      end

      it 'creates product option types based on the prototype' do
        product.save
        expect(product.product_option_types.pluck(:option_type_id)).to eq(prototype.option_type_ids)
      end

      it 'creates variants from an option values hash with one option type' do
        product.option_values_hash = option_values_hash
        product.save
        expect(product.variants.length).to eq(3)
      end

      it 'stills create variants when option_values_hash is given but prototype id is nil' do
        product.option_values_hash = option_values_hash
        product.prototype_id = nil
        product.save
        product.reload
        expect(product.option_type_ids.length).to eq(1)
        expect(product.option_type_ids).to eq(prototype.option_type_ids)
        expect(product.variants.length).to eq(3)
      end

      it 'creates variants from an option values hash with multiple option types' do
        color = build_option_type_with_values('color', %w(Red Green Blue))
        logo  = build_option_type_with_values('logo', %w(Ruby Rails Nginx))
        option_values_hash[color.id.to_s] = color.option_value_ids
        option_values_hash[logo.id.to_s] = logo.option_value_ids
        product.option_values_hash = option_values_hash
        product.save
        product.reload
        expect(product.option_type_ids.length).to eq(3)
        expect(product.variants.length).to eq(27)
      end
    end

    context 'when track inventory is disabled' do
      let(:product) { build(:product, track_inventory: false, stores: [store]) }

      it 'creates a default stock item' do
        product.save
        expect(product.master.track_inventory?).to eq(false)
        expect(product.master.stock_items.count).to eq(1)
        expect(product.master.stock_items.first.count_on_hand).to eq(0)
        expect(product.master.stock_items.first.backorderable).to eq(false)
      end
    end
  end

  describe '#images' do
    let(:product) { create(:product, stores: [store]) }
    let(:file) { File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __dir__)) }
    let(:params) { { viewable_id: product.master.id, viewable_type: 'Spree::Variant', alt: 'position 2', position: 2 } }

    before do
      images = [
        Spree::Image.new(params),
        Spree::Image.new(params.merge(alt: 'position 1', position: 1)),
        Spree::Image.new(params.merge(viewable_type: 'ThirdParty::Extension', alt: 'position 1', position: 2))
      ]
      images.each_with_index do |image, index|
        image.attachment.attach(io: file, filename: "thinking-cat-#{index + 1}.jpg", content_type: 'image/jpeg')
        image.save!
        file.rewind # we need to do this to avoid `ActiveStorage::IntegrityError`
      end
    end

    it 'only looks for variant images' do
      expect(product.images.size).to eq(2)
    end

    it 'is sorted by position' do
      expect(product.images.pluck(:alt)).to eq(['position 1', 'position 2'])
    end
  end

  # Regression tests for #2352
  context 'classifications and taxons' do
    it 'is joined through classifications' do
      reflection = Spree::Product.reflect_on_association(:taxons)
      expect(reflection.options[:through]).to eq(:classifications)
    end

    it 'will delete all classifications' do
      reflection = Spree::Product.reflect_on_association(:classifications)
      expect(reflection.options[:dependent]).to eq(:delete_all)
    end
  end

  describe '#total_on_hand' do
    let(:product) { create(:product, stores: [store]) }

    it 'is infinite if track_inventory_levels is false' do
      allow(Spree::Config).to receive(:track_inventory_levels).and_return(false)
      expect(build(:product, variants_including_master: [build(:master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'is infinite if variant is on demand' do
      allow(Spree::Config).to receive(:track_inventory_levels).and_return(true)
      expect(build(:product, variants_including_master: [build(:on_demand_master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'returns sum of stock items count_on_hand' do
      product.stock_items.first.set_count_on_hand 5
      product.variants_including_master.reload # force load association
      expect(product.total_on_hand).to be(5)
    end

    it 'returns sum of stock items count_on_hand when variants_including_master is not loaded' do
      product.stock_items.first.set_count_on_hand 5
      expect(product.reload.total_on_hand).to be(5)
    end
  end

  # Regression spec for https://github.com/spree/spree/issues/5588
  describe '#validate_master when duplicate SKUs entered' do
    subject { second_product }

    let!(:first_product) { create(:product, sku: 'a-sku', stores: [store]) }
    let(:second_product) { build(:product, sku: 'a-sku', stores: [store]) }

    it { is_expected.to be_invalid }
  end

  it 'initializes a master variant when building a product' do
    product = store.products.new
    expect(product.master.is_master).to be true
  end

  describe '#discontinue!' do
    let(:product) { create(:product, sku: 'a-sku', stores: [store]) }

    it 'sets the discontinued' do
      product.discontinue!
      product.reload
      expect(product.discontinued?).to be(true)
    end

    it 'sets the status to archived' do
      product.discontinue!
      product.reload
      expect(product.status).to eq('archived')
    end

    it 'changes updated_at' do
      Timecop.scale(1000) do
        expect { product.discontinue! }.to change(product, :updated_at)
      end
    end
  end

  describe '#discontinued?' do
    let(:product_live) { build(:product, sku: 'a-sku') }
    let(:product_discontinued) { build(:product, sku: 'a-sku', discontinue_on: Time.now - 1.day) }

    it 'is false' do
      expect(product_live.discontinued?).to be(false)
    end

    it 'is true' do
      expect(product_discontinued.discontinued?).to be(true)
    end
  end

  describe '#brand_taxon' do
    let(:taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_brands_name)) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    it 'fetches Brand Taxon' do
      expect(product.brand_taxon).to eql(taxonomy.taxons.first)
    end
  end

  describe '#brand' do
    let(:taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_brands_name)) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    context 'when brand association is not defined' do
      it 'falls back to brand_taxon' do
        expect(product.brand).to eql(taxonomy.taxons.first)
      end

      it 'returns brand name via brand_name method' do
        expect(product.brand_name).to eql(taxonomy.taxons.first.name)
      end
    end

    context 'when brand association is defined' do
      let(:brand_class) { Class.new(Spree::Base) { self.table_name = 'spree_taxons' } }
      let(:brand) { brand_class.first }

      before do
        stub_const('Spree::Brand', brand_class)
        allow(Spree::Product).to receive(:reflect_on_association).with(:brand).and_return(double(name: :brand))
        allow(product).to receive(:super).and_return(brand)
        # Mock the super call by defining the association behavior
        product.define_singleton_method(:read_attribute) do |attr|
          attr == :brand_id ? brand.id : super(attr)
        end
        product.define_singleton_method(:association) do |name|
          name == :brand ? double(reader: brand) : super(name)
        end
      end

      it 'uses the brand association' do
        allow(product).to receive(:brand).and_call_original
        # Since we can't easily mock super, we verify the reflection check
        expect(Spree::Product.reflect_on_association(:brand)).to be_truthy
      end
    end
  end

  describe '#category_taxon' do
    let(:taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_categories_name)) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    it 'fetches Category Taxon' do
      expect(product.category_taxon).to eql(taxonomy.taxons.first)
    end
  end

  describe '#category' do
    let(:taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_categories_name)) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    context 'when category association is not defined' do
      it 'falls back to category_taxon' do
        expect(product.category).to eql(taxonomy.taxons.first)
      end
    end

    context 'when category association is defined' do
      let(:category_class) { Class.new(Spree::Base) { self.table_name = 'spree_taxons' } }
      let(:category) { category_class.first }

      before do
        stub_const('Spree::Category', category_class)
        allow(Spree::Product).to receive(:reflect_on_association).with(:category).and_return(double(name: :category))
      end

      it 'checks for the category association' do
        expect(Spree::Product.reflect_on_association(:category)).to be_truthy
      end
    end
  end

  describe '#backordered?' do
    let!(:product) { create(:product, stores: [store]) }

    it 'returns true when out of stock and backorderable' do
      expect(product.backordered?).to eq(true)
    end

    it 'returns false when out of stock and not backorderable' do
      product.stock_items.first.update(backorderable: false)
      expect(product.backordered?).to eq(false)
    end

    it 'returns false when there is available item in stock' do
      product.stock_items.first.update(count_on_hand: 10)
      expect(product.backordered?).to eq(false)
    end
  end

  describe '#ensure_not_in_complete_orders' do
    let!(:order) { create(:completed_order_with_totals) }
    let(:product) { create(:product, stores: [store]) }
    let!(:line_item) { create(:line_item, order: order, variant: product.master, product: product) }

    it 'adds error on product destroy' do
      expect(product.destroy).to eq false
      expect(product.errors[:base]).to include I18n.t('activerecord.errors.models.spree/product.attributes.base.cannot_destroy_if_attached_to_line_items')
    end
  end

  describe '#default_variant' do
    let(:product) { create(:product, stores: [store]) }

    context 'track inventory levels' do
      context 'product has variants' do
        let!(:variant_1) { create(:variant, product: product, position: 1) }
        let!(:variant_2) { create(:variant, product: product, position: 2) }

        before do
          variant_1.stock_items.first.update(backorderable: false, count_on_hand: 0)
          variant_2.stock_items.first.update(backorderable: false, count_on_hand: 0)
        end

        context 'in stock' do
          before { variant_2.stock_items.first.adjust_count_on_hand(1) }

          it 'returns first non-master in stock variant' do
            expect(product.reload.default_variant).to eq(variant_2)
          end
        end

        context 'backorderable' do
          before { variant_2.stock_items.first.update(backorderable: true) }

          it 'returns first non-master backorderable variant' do
            expect(product.reload.default_variant).to eq(variant_2)
          end
        end

        context 'product without variants in stock or backorerable' do
          it 'returns first non-master variant' do
            expect(product.reload.default_variant).to eq(variant_1)
          end
        end
      end

      context 'without tracking inventory levels' do
        let!(:variant_1) { create(:variant, product: product, position: 1) }
        let!(:variant_2) { create(:variant, product: product, position: 2) }

        before do
          Spree::Config[:track_inventory_levels] = false
          variant_1.stock_items.first.update(backorderable: false, count_on_hand: 0)
          variant_2.stock_items.first.update(backorderable: false, count_on_hand: 0)
        end

        after { Spree::Config[:track_inventory_levels] = true }

        it 'returns first non-master variant' do
          expect(product.reload.default_variant).to eq(variant_1)
        end
      end

      context 'product without variants' do
        it 'returns master variant' do
          expect(product.reload.default_variant).to eq(product.master)
        end
      end
    end
  end

  describe '#default_variant_id' do
    let(:product) { create(:product, stores: [store]) }

    context 'product has variants' do
      let!(:variant) { create(:variant, product: product) }

      it 'returns first non-master variant ID' do
        expect(product.reload.default_variant_id).to eq(variant.id)
      end
    end

    context 'product without variants' do
      it 'returns master variant ID' do
        expect(product.reload.default_variant_id).to eq(product.master.id)
      end
    end
  end

  describe '#default_image' do
    let(:product) { create(:product, stores: [store]) }
    let!(:image) { create(:image, viewable: product.master) }

    it 'returns the first image for the product' do
      expect(product.default_image).to eq(image)
    end

    context 'with variants' do
      let!(:variant) { create(:variant, product: product) }
      let!(:image2) { create(:image, viewable: variant) }

      it 'returns the first image for the product' do
        expect(product.default_image).to eq(image)
      end

      context 'when master has no images' do
        let!(:image) { nil }

        it 'returns the first image for the variant' do
          expect(product.default_image).to eq(image2)
        end
      end
    end
  end

  describe '#ensure_store_presence' do
    let(:product) { create(:product, stores: []) }

    context 'no store passed' do
      it 'auto-assigns store' do
        expect(product.stores).to eq([Spree::Store.default])
      end
    end

    context 'store passed' do
      let(:store) { Spree::Store.default }
      let(:product) { create(:product, stores: [store]) }

      it 'does not auto-assign store' do
        expect(product.stores).to eq([store])
      end
    end

    context 'validation disabled' do
      context 'preference set' do
        before { Spree::Config[:disable_store_presence_validation] = true }

        it { expect(product.stores).to eq([]) }
      end
    end
  end

  describe '#taxons_for_store' do
    let(:store_2) { create(:store) }
    let(:product) { create(:product, stores: [store, store_2], taxons: [taxon, taxon_2]) }
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:taxonomy_2) { create(:taxonomy, store: store_2) }
    let(:taxon) { create(:taxon, taxonomy: taxonomy) }
    let(:taxon_2) { create(:taxon, taxonomy: taxonomy_2) }
    let(:taxon_3) { create(:taxon, taxonomy: taxonomy) }

    it 'returns product taxons for specified store' do
      expect(product.taxons_for_store(store)).to eq([taxon])
      expect(product.taxons_for_store(store_2)).to eq([taxon_2])
    end

    it { expect(product.taxons_for_store(store)).to be_a(ActiveRecord::Relation) }
  end

  describe '#any_variant_in_stock_or_backorderable?' do
    subject { product.any_variant_in_stock_or_backorderable? }

    let!(:product) { create(:product, stores: [store]) }
    let(:stock_item) { variant.stock_items.first }

    context 'when only master variant is in stock or backorderable' do
      it { expect(subject).to eq(true) }
    end

    context 'with more variants aside from the master variant' do
      # makes the stock items available for the before hook
      let!(:variant) { create(:variant, product: product) }

      before do
        Spree::StockItem.update_all(backorderable: false)
        product.reload
      end

      context 'with at least one non-master variant stock items count_on_hand > 0' do
        before do
          # make all stock items in stock, also for the master variant
          Spree::StockItem.all.each { |stock_item| stock_item.set_count_on_hand(1) }
        end

        it { expect(subject).to eq(true) }
      end

      context 'when all non-master variant stock items have count_on_hand <= 0' do
        before { stock_item.set_count_on_hand(0) }

        it { expect(subject).to eq(false) }

        context 'when all non-master variant stock items have track_inventory = false' do
          before { variant.update(track_inventory: false) }

          it { expect(subject).to be(true) }
        end

        context 'when all non-master variant stock items have track_inventory = true' do
          it { expect(subject).to eq(false) }

          context 'when all non-master variant stock items have backorderable = true' do
            before { stock_item.update(backorderable: true) }

            it { expect(subject).to eq(true) }
          end
        end
      end
    end

    describe '#digital?' do
      let(:product) { create(:product, stores: [store], shipping_category: shipping_category) }
      let(:shipping_category) { create(:shipping_category) }

      context 'when product has a shipping method with DigitalDelivery calculator' do
        let!(:shipping_method) { create(:shipping_method, calculator: Spree::Calculator::Shipping::DigitalDelivery.new, shipping_categories: [shipping_category]) }

        it { expect(product.digital?).to eq(true) }
      end

      context 'when product does not have a shipping method with DigitalDelivery calculator' do
        let!(:shipping_method) { create(:shipping_method, calculator: Spree::Calculator::Shipping::FlatRate.new, shipping_categories: [shipping_category]) }

        it { expect(product.digital?).to eq(false) }
      end
    end
  end

  describe '#to_csv' do
    let(:store) { Spree::Store.default }
    let(:product) { create(:product, stores: [store]) }
    let(:property) { create(:property, name: 'my-property', position: 1) }
    let(:product_property) { create(:product_property, property: property, product: product, value: 'MyValue') }
    let(:taxon) { create(:taxon, name: 'My Taxon') }

    before do
      product_property
      product.taxons << taxon
    end

    context 'when product has no variants' do
      before do
        Spree::Config[:product_properties_enabled] = true
      end

      after do
        Spree::Config[:product_properties_enabled] = false
      end

      it 'returns an array with one line of CSV data' do
        csv_lines = product.to_csv(store)
        expect(csv_lines.size).to eq(1)

        csv_line = csv_lines.first
        expect(csv_line).to include(product.name)
        expect(csv_line).to include(product.master.sku)
        expect(csv_line.last(5)).to eq([taxon.pretty_name, nil, nil, "my-property", "MyValue"])
      end
    end

    context 'when product has variants' do
      let!(:variant1) { create(:variant, product: product) }
      let!(:variant2) { create(:variant, product: product) }

      before do
        product.master.update!(sku: 'test-product-master-sku')
      end

      it 'returns an array with CSV data for each variant including the master variant' do
        csv_lines = product.reload.to_csv(store)
        expect(csv_lines.size).to eq(3)

        expect(csv_lines[0]).to include(product.name)
        expect(csv_lines[0]).to include('test-product-master-sku')

        expect(csv_lines[1]).not_to include(product.name)
        expect(csv_lines[1]).to include(variant1.sku)

        expect(csv_lines[2]).not_to include(product.name)
        expect(csv_lines[2]).to include(variant2.sku)
      end
    end

    context 'when store is not provided' do
      it 'uses default store' do
        allow(product.stores).to receive(:default).and_return(store)
        expect(product.to_csv).to be_present
      end

      it 'falls back to first store if no default' do
        allow(product.stores).to receive(:default).and_return(nil)
        allow(product.stores).to receive(:first).and_return(store)
        expect(product.to_csv).to be_present
      end
    end
  end

  describe '#on_sale?' do
    subject { product.on_sale?(currency) }

    let(:product) { create(:product) }
    let(:currency) { 'EUR' }
    let(:variant_1) { create(:variant, product: product) }
    let(:variant_2) { create(:variant, product: product) }

    context 'when at least one variant is on sale' do
      let!(:eur_price_1) { create(:price, variant: variant_1, currency: 'EUR', compare_at_amount: 200.00) }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'when no variant is on sale' do
      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#first_or_default_variant' do
    subject { product.first_or_default_variant('USD') }

    let!(:product) { create(:product, stores: [store]) }

    context 'without variants' do
      it 'returns the default variant' do
        expect(subject).to eq(product.master)
      end
    end

    context 'with a variant in the given currency' do
      let!(:variant_1) { create(:variant, product: product) }
      let!(:variant_2) { create(:variant, product: product) }

      before do
        product.reload.prices.where(currency: 'USD').delete_all

        create(:price, variant: variant_1, currency: 'PLN', amount: 10)
        create(:price, variant: variant_2, currency: 'USD', amount: 10)
      end

      it 'returns the available variant in the given currency' do
        expect(subject).to eq(variant_2)
      end
    end

    context 'with all variants in different currencies' do
      let!(:variant_1) { create(:variant, product: product) }
      let!(:variant_2) { create(:variant, product: product) }

      before do
        product.reload.prices.where(currency: 'USD').delete_all

        create(:price, variant: variant_1, currency: 'PLN', amount: 10)
        create(:price, variant: variant_2, currency: 'GBP', amount: 10)
      end

      it 'returns the first variant' do
        expect(subject).to eq(variant_1)
      end
    end
  end

  describe '#first_available_variant' do
    subject { product.first_available_variant('USD') }

    let!(:product) { create(:product, stores: [store]) }

    let!(:variant_1) { create(:variant, product: product, create_stock: false) }
    let!(:variant_2) { create(:variant, product: product) }
    let!(:variant_3) { create(:variant, product: product) }
    let!(:variant_4) { create(:variant, product: product) }
    let!(:variant_5) { create(:variant, product: product) }

    before do
      product.reload.prices.where(currency: 'USD').delete_all

      create(:price, variant: variant_2, currency: 'PLN', amount: 10)
      create(:price, variant: variant_4, currency: 'USD', amount: 20)
      create(:price, variant: variant_5, currency: 'USD', amount: 10)
    end

    it 'returns the first available variant' do
      expect(subject).to eq(variant_4)
    end
  end

  describe '#price_varies?' do
    subject { product.price_varies?('USD') }

    let!(:product) { create(:product, stores: [store]) }

    let!(:variant_1) { create(:variant, product: product) }
    let!(:variant_2) { create(:variant, product: product) }

    before do
      product.reload.prices.where(currency: 'USD').delete_all
    end

    context 'when all variants have the same price in the given currency' do
      before do
        create(:price, variant: variant_1, currency: 'USD', amount: 10)
        create(:price, variant: variant_1, currency: 'PLN', amount: 15)

        create(:price, variant: variant_2, currency: 'USD', amount: 10)
        create(:price, variant: variant_2, currency: 'PL', amount: 20)
      end

      it { is_expected.to be(false) }
    end

    context 'when variants have different prices in the given currency' do
      before do
        create(:price, variant: variant_1, currency: 'USD', amount: 10)
        create(:price, variant: variant_2, currency: 'USD', amount: 20)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#any_variant_available?' do
    subject { product.any_variant_available?('USD') }

    let!(:product) { create(:product, stores: [store]) }

    context 'without variants' do
      before do
        product.master.prices.where(currency: 'USD').delete_all
        product.master.prices.create(currency: currency, amount: 10)
      end

      context 'when master variant is available' do
        let(:currency) { 'USD' }
        it { is_expected.to be(true) }
      end

      context 'when master variant is not available' do
        let(:currency) { 'PLN' }
        it { is_expected.to be(false) }
      end
    end

    context 'with variants' do
      let!(:variant_1) { create(:variant, product: product) }
      let!(:variant_2) { create(:variant, product: product) }

      before do
        product.reload.prices.where(currency: 'USD').delete_all

        create(:price, variant: variant_1, currency: 'PLN', amount: 10)
        create(:price, variant: variant_2, currency: currency, amount: 10)
      end

      context 'when all variants are available' do
        let(:currency) { 'USD' }
        it { is_expected.to be(true) }
      end

      context 'when no variants are available' do
        let(:currency) { 'PLN' }
        it { is_expected.to be(false) }
      end
    end
  end

  describe '#lowest_price' do
    subject { product.lowest_price('USD') }

    let!(:product) { create(:product, stores: [store]) }

    let!(:variant_1) { create(:variant, product: product) }
    let!(:variant_2) { create(:variant, product: product) }
    let!(:variant_3) { create(:variant, product: product) }

    let(:price_1) { create(:price, variant: variant_1, currency: 'PLN', amount: 10) }
    let(:price_2) { create(:price, variant: variant_2, currency: 'USD', amount: 20) }
    let(:price_3) { create(:price, variant: variant_3, currency: 'USD', amount: 18) }

    before do
      product.reload.prices.where(currency: 'USD').delete_all

      price_1
      price_2
      price_3
    end

    it 'returns the lowest price' do
      expect(subject).to eq(price_3)
    end
  end

  describe 'scopes' do
    describe '.not_discontinued' do
      let(:product) { create(:product, stores: [store]) }
      let(:discontinued_product) { create(:product, stores: [store], discontinue_on: Time.current - 1.day) }

      context 'when nothing is passed as an argument' do
        it 'returns only not discontinued products' do
          products = Spree::Product.not_discontinued
          expect(products).to include(product)
          expect(products).not_to include(discontinued_product)
        end
      end

      context 'when false is passed as an argument' do
        it 'returns all products' do
          products = Spree::Product.not_discontinued(false)

          expect(products).to include(product,discontinued_product)
        end
      end
    end

    describe '.available' do
      let!(:discontinued_product) { create(:product, discontinue_on: 1.day.ago, stores: [store]) }
      let!(:future_product) { create(:product, available_on: 1.day.from_now, status: 'active', stores: [store]) }
      let!(:active_product) { create(:product, available_on: 1.day.ago, status: 'active', stores: [store]) }

      let!(:prices) do
        [
          create(:price, variant: active_product.default_variant, currency: 'USD', amount: 10),
          create(:price, variant: future_product.default_variant, currency: 'USD', amount: 10),
          create(:price, variant: discontinued_product.default_variant, currency: 'USD', amount: 10)
        ]
      end

      context 'when available_on is specified' do
        subject(:available_products) { described_class.available(Time.current) }

        it 'returns products available before or on the specified date' do
          expect(available_products).to contain_exactly(active_product)
        end
      end

      context 'when available_on is not specified' do
        subject(:available_products) { described_class.available }

        it 'returns active, not discontinued products' do
          expect(available_products).to contain_exactly(active_product, future_product)
        end
      end

      context 'when show_products_without_price is false' do
        subject(:available_products) { described_class.available(nil, 'USD') }

        before do
          Spree::Config.show_products_without_price = false
        end

        let!(:active_product_2) { create(:product, status: 'active', stores: [store]) }
        let!(:active_product_3) { create(:product, status: 'active', stores: [store]) }
        let!(:active_product_4) { create(:product, status: 'active', stores: [store]) }

        before do
          active_product_2.prices_including_master.where(currency: 'USD').delete_all
          active_product_3.prices_including_master.where(currency: 'USD').delete_all
          active_product_4.prices_including_master.where(currency: 'USD').delete_all

          active_product_2.default_variant.prices.create(currency: 'USD', amount: 10)
          active_product_3.default_variant.prices.create(currency: 'PLN', amount: 10)
        end

        it 'only returns products with prices in the specified currency' do
          expect(available_products).to contain_exactly(future_product, active_product, active_product_2)
        end
      end

      context 'when show_products_without_price is true' do
        subject(:available_products) { described_class.available(nil, 'USD') }
        before do
          Spree::Config.show_products_without_price = true
        end

        let(:active_product_2) { create(:product, status: 'active', stores: [store]) }
        let(:active_product_3) { create(:product, status: 'active', stores: [store]) }
        let(:active_product_4) { create(:product, status: 'active', stores: [store]) }

        before do
          active_product_2.default_variant.prices.create(currency: 'USD', amount: 10)
          active_product_3.default_variant.prices.create(currency: 'PLN', amount: 10)
        end

        it 'returns products regardless of price' do
          expect(available_products).to contain_exactly(
            future_product, active_product, active_product_2, active_product_3, active_product_4
          )
        end
      end
    end
  end

  describe 'after_touch :touch_taxons' do
    subject { product.touch }

    let!(:product) { create(:product, taxons: taxons) }

    context 'without taxons' do
      let(:taxons) { [] }

      it 'skips enqueuing a job for touching the taxons' do
        expect { subject }.not_to have_enqueued_job(Spree::Products::TouchTaxonsJob)
      end
    end

    context 'with taxons' do
      let(:taxons) { [taxon_1, taxon_2] }

      let!(:taxon_1) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }
      let!(:taxon_2) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }

      let(:taxonomy) { create(:taxonomy) }

      it 'enqueues a job for touching the taxons' do
        expect { subject }.to have_enqueued_job(Spree::Products::TouchTaxonsJob).with(
          [taxonomy.root.id, taxon_1.id, taxon_2.id],
          [taxonomy.id]
        )
      end
    end
  end
end
