require 'spec_helper'

module ThirdParty
  class Extension < Spree::Base
    # nasty hack so we don't have to create a table to back this fake model
    self.table_name = 'spree_products'
  end
end

describe Spree::Product, type: :model do
  it_behaves_like 'metadata'

  let!(:store) { create(:store) }

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

            expect(product.send("#{method_name}?")).to eq false
          end

          it "returns true if variant is #{method_name.humanize.downcase}" do
            variant.stock_items.update_all(backorderable: true) if %w[purchasable backorderable].include?(method_name)
            variant.stock_items.update_all(count_on_hand: 10) if method_name == 'in_stock'

            expect(product.send("#{method_name}?")).to eq true
          end
        end

        context 'without variants' do
          it "returns false if master is not #{method_name.humanize.downcase}" do
            product.master.stock_items.update_all(backorderable: false) if %w[purchasable backorderable].include?(method_name)
            product.master.stock_items.update_all(count_on_hand: 0) if method_name == 'in_stock'

            expect(product.send("#{method_name}?")).to eq false
          end

          it "returns true if master is #{method_name.humanize.downcase}" do
            product.master.stock_items.update_all(backorderable: true) if %w[purchasable backorderable].include?(method_name)
            product.master.stock_items.update_all(count_on_hand: 10) if method_name == 'in_stock'

            expect(product.send("#{method_name}?")).to eq true
          end
        end
      end
    end

    context '#duplicate' do
      before do
        allow(product).to receive_messages taxons: [create(:taxon)], stores: [store]
      end

      it 'duplicates product' do
        clone = product.duplicate
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
          clone = product.duplicate
          expect(clone.name(locale: :fr)).to eq ('COPY OF ' + product.name(locale: :fr))
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
          expect(product.master).to receive(:save!)
          product.save
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
      context '#destroy' do
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

      context '#destroy' do
        it 'sets deleted_at value' do
          product.destroy
          expect(product.deleted_at).not_to be_nil
          expect(product.variants_including_master.all? { |v| !v.deleted_at.nil? }).to be true
        end
      end
    end

    context '#price' do
      # Regression test for #1173
      it 'strips non-price characters' do
        product.price = '$10'
        expect(product.price).to eq(10.0)
      end
    end

    context '#display_price' do
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

    context '#available?' do
      it 'is available if status is set to active' do
        product.status = 'active'
        expect(product).to be_available
      end

      it 'is not available if destroyed' do
        product.destroy
        expect(product).not_to be_available
      end
    end

    context '#can_supply?' do
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

    context 'slugs' do
      it 'normalizes slug on update validation' do
        product.slug = 'hey//joe'
        product.valid?
        expect(product.slug).not_to match '/'
      end

      it 'stores old slugs in FriendlyIds history' do
        expect(product).to receive(:create_slug)
        # Set it, otherwise the create_slug method avoids writing a new one
        product.slug = 'custom-slug'
        product.run_callbacks :save
      end

      context 'when product destroyed' do
        it 'renames slug' do
          product.destroy
          expect(product.slug).to match(/[0-9]+_product-[0-9]+/)
        end

        context 'when more than one translation exists' do
          before {
            product.send(:slug=, "french-slug", locale: :fr)
            product.save!
          }

          it 'renames slug for all translations' do
            product.destroy
            expect(product.slug).to match(/[0-9]+_product-[0-9]+/)
            expect(product.translations.with_deleted.where(locale: :fr).first.slug).to match(/[0-9]+_french-slug/)
          end
        end

        context 'when slug is already at or near max length' do
          before do
            product.slug = 'x' * 255
            product.save!
          end

          it 'truncates renamed slug to ensure it remains within length limit' do
            product.destroy
            expect(product.slug.length).to eq 255
          end
        end
      end

      it 'validates slug uniqueness' do
        existing_product = product
        new_product = create(:product, stores: [store])
        new_product.slug = existing_product.slug

        expect(new_product.valid?).to eq false
      end

      it "falls back to 'name-sku' for slug if regular name-based slug already in use" do
        product1 = build(:product, stores: [store])
        product1.name = 'test'
        product1.sku = '123'
        product1.save!

        product2 = build(:product, stores: [store])
        product2.name = 'test'
        product2.sku = '456'
        product2.save!

        expect(product2.slug).to eq 'test-456'
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

      it 'keeps the history when the product is destroyed' do
        @product.destroy

        expect(@product.slugs.with_deleted).not_to be_empty
      end

      it 'keeps translations when product is destroyed' do
        @product.destroy

        expect(@product.name).not_to be_empty
      end

      it 'updates the history when the product is restored' do
        @product.destroy

        @product.restore(recursive: true)

        latest_slug = @product.slugs.find_by slug: @product.slug
        expect(latest_slug).not_to be_nil
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
        expect(product_pl_translation.meta_keywords).to eq('PL meta keywords')
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
    context '#possible_promotions' do
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
  end

  context '#images' do
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

  context '#total_on_hand' do
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
  context '#validate_master when duplicate SKUs entered' do
    subject { second_product }

    let!(:first_product) { create(:product, sku: 'a-sku', stores: [store]) }
    let(:second_product) { build(:product, sku: 'a-sku', stores: [store]) }

    it { is_expected.to be_invalid }
  end

  it 'initializes a master variant when building a product' do
    product = store.products.new
    expect(product.master.is_master).to be true
  end

  context '#discontinue!' do
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

  context '#discontinued?' do
    let(:product_live) { build(:product, sku: 'a-sku') }
    let(:product_discontinued) { build(:product, sku: 'a-sku', discontinue_on: Time.now - 1.day) }

    it 'is false' do
      expect(product_live.discontinued?).to be(false)
    end

    it 'is true' do
      expect(product_discontinued.discontinued?).to be(true)
    end
  end

  context '#brand' do
    let(:taxonomy) { create(:taxonomy, name: I18n.t('spree.taxonomy_brands_name')) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    it 'fetches Brand Taxon' do
      expect(product.brand).to eql(taxonomy.taxons.first)
    end
  end

  context '#category' do
    let(:taxonomy) { create(:taxonomy, name: I18n.t('spree.taxonomy_categories_name')) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first], stores: [store]) }

    it 'fetches Category Taxon' do
      expect(product.category).to eql(taxonomy.taxons.first)
    end
  end

  context '#backordered?' do
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

  context '#default_variant' do
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
            expect(product.default_variant).to eq(variant_2)
          end
        end

        context 'backorderable' do
          before { variant_2.stock_items.first.update(backorderable: true) }

          it 'returns first non-master backorderable variant' do
            expect(product.default_variant).to eq(variant_2)
          end
        end

        context 'product without variants in stock or backorerable' do
          it 'returns first non-master variant' do
            expect(product.default_variant).to eq(variant_1)
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
          expect(product.default_variant).to eq(variant_1)
        end
      end

      context 'product without variants' do
        it 'returns master variant' do
          expect(product.default_variant).to eq(product.master)
        end
      end
    end
  end

  context '#default_variant_id' do
    let(:product) { create(:product, stores: [store]) }

    context 'product has variants' do
      let!(:variant) { create(:variant, product: product) }

      it 'returns first non-master variant ID' do
        expect(product.default_variant_id).to eq(variant.id)
      end
    end

    context 'product without variants' do
      it 'returns master variant ID' do
        expect(product.default_variant_id).to eq(product.master.id)
      end
    end
  end

  describe '#default_variant_cache_key' do
    let(:product) { create(:product, stores: [store]) }
    let(:key) { product.send(:default_variant_cache_key) }

    context 'with inventory tracking' do
      before { Spree::Config[:track_inventory_levels] = true }

      it 'returns proper key' do
        expect(key).to eq("spree/default-variant/#{product.cache_key_with_version}/true")
      end
    end

    context 'without invenrtory tracking' do
      before { Spree::Config[:track_inventory_levels] = false }

      it 'returns proper key' do
        expect(key).to eq("spree/default-variant/#{product.cache_key_with_version}/false")
      end
    end

    describe '#requires_shipping_category?' do
      let(:product) { build(:product, shipping_category: nil) }

      it { expect(product.save).to eq(false) }
    end

    describe '#downcase_slug' do
      let(:product) { build(:product, slug: 'My-slug') }

      it { expect { product.valid? }.to change(product, :slug).to('my-slug') }
    end
  end

  describe '#ensure_store_presence' do
    let(:valid_record) { build(:product, stores: [create(:store)]) }
    let(:invalid_record) { build(:product, stores: []) }

    it { expect(valid_record).to be_valid }
    it { expect(invalid_record).not_to be_valid }

    context 'validation disabled' do
      context 'method overwrite' do
        before { allow_any_instance_of(described_class).to receive(:disable_store_presence_validation?).and_return(true) }

        it { expect(valid_record).to be_valid }
        it { expect(invalid_record).to be_valid }
      end

      context 'preference set' do
        before { Spree::Config[:disable_store_presence_validation] = true }

        it { expect(valid_record).to be_valid }
        it { expect(invalid_record).to be_valid }
      end
    end
  end

  describe '#taxons_for_store' do
    let(:store) { create(:store) }
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

      before { Spree::StockItem.update_all(backorderable: false) }

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

          it { expect(subject).to eq(true) }
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
      context 'when product is not digital' do
        let(:product) { create(:product, stores: [store]) }

        it { expect(product.digital?).to eq(false) }
      end

      context 'when product is digital' do
        let(:product) { create(:product, stores: [store], shipping_category: create(:shipping_category, name: 'Digital')) }

        it { expect(product.digital?).to eq(true) }
      end
    end
  end

  describe '#localized_slugs_for_store' do
    let(:store) { create(:store, default_locale: 'fr', supported_locales: 'en,pl,fr') }
    let(:product) { create(:product, stores: [store], name: 'Test product', slug: 'test-slug-en') }
    let!(:product_translation_fr) { product.translations.create(slug: 'test_slug_fr', locale: 'fr') }

    before { Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) }

    subject { product.localized_slugs_for_store(store) }

    context 'when there are slugs in locales not supported by the store' do
      let!(:product_translation_pl) { product.translations.create(slug: 'test_slug_pl', locale: 'pl') }
      let!(:product_translation_de) { product.translations.create(slug: 'test_slug_de', locale: 'de') }

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-slug-fr',
          'pl' => 'test-slug-pl'
        }
      end

      it 'returns only slugs in locales supported by the store' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when one of the supported locales does not have a translation' do
      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-slug-fr',
          'pl' => 'test-slug-fr'
        }
      end

      it "falls back to store's default locale" do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from name when slug field is empty' do
      before do
        product_translation_fr.update(slug: nil, name: "slug from name")
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'slug-from-name',
          'pl' => 'slug-from-name'
        }
      end

      it "saves slugs generated from name" do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from default locale name when name and slug for translation is empty' do
      before do
        product_translation_fr.update(slug: nil, name: nil)
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-product',
          'pl' => 'test-product'
        }
      end

      it 'saves slugs generated from fallback name' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from invalid slug format' do
      before do
        product_translation_fr.update(slug: "slug with_spaces")
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'slug-with-spaces',
          'pl' => 'slug-with-spaces'
        }
      end

      it 'saves slugs in valid format' do
        expect(subject).to match(expected_slugs)
      end
    end
  end
end
