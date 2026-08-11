require 'spec_helper'

RSpec.describe Spree::Category, type: :model do
  let(:store) { @default_store }

  # The permalink is the category's full path, so it alone identifies a category
  # within a store. Names are unconstrained — the path disambiguates them.
  describe 'permalink uniqueness' do
    it 'allows the same permalink in different stores' do
      other = create(:store)
      described_class.create!(name: 'Shoes', store: store)

      expect(described_class.new(name: 'Shoes', store: other)).to be_valid
    end

    it 'rejects a duplicate permalink within the same store' do
      described_class.create!(name: 'Shoes', store: store)

      expect(described_class.new(name: 'Shoes', store: store)).not_to be_valid
    end

    # Guards the index itself, not the validation: top-level categories have
    # parent_id IS NULL, and the previous (permalink, parent_id, taxonomy_id)
    # index left them unconstrained because unique indexes treat NULLs as distinct.
    it 'enforces it at the database level, including for top-level categories' do
      described_class.create!(name: 'Shoes', store: store)
      duplicate = described_class.new(name: 'Boots', permalink: 'shoes', store: store)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same name under different parents, since the paths differ' do
      men = described_class.create!(name: 'Men', store: store)
      women = described_class.create!(name: 'Women', store: store)
      described_class.create!(name: 'Shoes', parent: men, store: store)

      sibling = described_class.new(name: 'Shoes', parent: women, store: store)

      expect(sibling).to be_valid
      expect { sibling.save! }.not_to raise_error
      expect(sibling.reload.permalink).to eq('women/shoes')
    end

    # The model validation is case-insensitive while the database index is not,
    # so a case variant has to be caught before it reaches the index.
    it 'rejects a permalink that differs only by case' do
      described_class.create!(name: 'Shoes', store: store)
      duplicate = described_class.new(name: 'Other', permalink: 'SHOES', store: store)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:permalink]).to be_present
    end

    it 'generates lowercase permalinks, so mixed-case names cannot collide by case alone' do
      expect(described_class.create!(name: 'Mixed Case Name', store: store).permalink).to eq('mixed-case-name')
    end

    it 'rejects two categories sharing a parent and a name, whose paths collide' do
      men = described_class.create!(name: 'Men', store: store)
      described_class.create!(name: 'Shoes', parent: men, store: store)

      expect(described_class.new(name: 'Shoes', parent: men, store: store)).not_to be_valid
    end
  end

  describe 'parent store boundary' do
    it 'rejects a parent owned by another store' do
      foreign_parent = described_class.create!(name: 'Foreign', store: create(:store))
      child = described_class.new(name: 'Child', store: store, parent: foreign_parent)

      expect(child).not_to be_valid
      expect(child.errors[:parent]).to include('must belong to the same store')
    end

    it 'accepts a parent in the same store' do
      parent = described_class.create!(name: 'Local', store: store)

      expect(described_class.new(name: 'Child', store: store, parent: parent)).to be_valid
    end
  end

  describe 'products_count on destroy' do
    it 'decrements ancestors when a subcategory is destroyed' do
      parent = described_class.create!(name: 'Electronics', store: store)
      child = described_class.create!(name: 'Phones', parent: parent)
      create(:product_category, category: child, product: create(:product, store: store))
      expect(parent.reload.products_count).to eq(1)

      child.destroy

      expect(parent.reload.products_count).to eq(0)
    end

    it 'keeps the count from surviving siblings' do
      parent = described_class.create!(name: 'Electronics', store: store)
      phones = described_class.create!(name: 'Phones', parent: parent)
      laptops = described_class.create!(name: 'Laptops', parent: parent)
      create(:product_category, category: phones, product: create(:product, store: store))
      create(:product_category, category: laptops, product: create(:product, store: store))
      expect(parent.reload.products_count).to eq(2)

      phones.destroy

      expect(parent.reload.products_count).to eq(1)
    end

    it 'decrements every ancestor level when a mid-tree node is destroyed' do
      root = described_class.create!(name: 'Root', store: store)
      mid = described_class.create!(name: 'Mid', parent: root)
      leaf = described_class.create!(name: 'Leaf', parent: mid)
      create(:product_category, category: leaf, product: create(:product, store: store))
      expect(root.reload.products_count).to eq(1)

      mid.destroy # removes the mid + leaf subtree

      expect(root.reload.products_count).to eq(0)
    end

    it 'keeps a product still reachable through a surviving sibling (dedup)' do
      root = described_class.create!(name: 'Root', store: store)
      a = described_class.create!(name: 'A', parent: root)
      b = described_class.create!(name: 'B', parent: root)
      product = create(:product, store: store)
      create(:product_category, category: a, product: product)
      create(:product_category, category: b, product: product)
      expect(root.reload.products_count).to eq(1)

      a.destroy

      expect(root.reload.products_count).to eq(1)
    end
  end

  describe 'creation without a taxonomy' do
    it 'creates a parentless, store-owned top-level category' do
      category = described_class.new(name: 'Kitchen', store: store)
      expect(category).to be_valid
      category.save!

      expect(category.taxonomy).to be_nil
      expect(category.parent).to be_nil
      expect(category.store).to eq(store)
    end

    it 'does not require a taxonomy' do
      category = described_class.new(name: 'Kitchen', store: store)
      expect(category).to be_valid
      expect(category.errors[:taxonomy]).to be_empty
    end

    it 'copies the store from its parent' do
      parent = described_class.create!(name: 'Kitchen', store: store)
      child = described_class.create!(name: 'Pots', parent: parent)

      expect(child.store).to eq(store)
      expect(child.taxonomy).to be_nil
    end
  end

  describe 'store auto-resolution (#ensure_store)' do
    it 'falls back to the current store when none is given' do
      Spree::Current.store = store
      category = described_class.create!(name: 'Kitchen')

      expect(category.store).to eq(store)
    end

    it 'prefers an explicit store over the current store' do
      other = create(:store)
      Spree::Current.store = other

      category = described_class.create!(name: 'Kitchen', store: store)

      expect(category.store).to eq(store)
    end

    it 'prefers the parent store over the current store' do
      other = create(:store)
      Spree::Current.store = other
      parent = described_class.create!(name: 'Kitchen', store: store)

      child = described_class.create!(name: 'Pots', parent: parent)

      expect(child.store).to eq(store)
    end
  end

  describe '.for_store / .for_stores' do
    it 'finds categories by store_id' do
      category = described_class.create!(name: 'Kitchen', store: store)
      expect(described_class.for_store(store)).to include(category)
    end

    it 'excludes categories owned by another store' do
      other = create(:store)
      mine = described_class.create!(name: 'Mine', store: store)
      theirs = described_class.create!(name: 'Theirs', store: other)

      result = described_class.for_store(store)
      expect(result).to include(mine)
      expect(result).not_to include(theirs)
    end

    it 'finds categories across multiple stores' do
      other = create(:store)
      mine = described_class.create!(name: 'Mine', store: store)
      theirs = described_class.create!(name: 'Theirs', store: other)

      expect(described_class.for_stores([store, other])).to include(mine, theirs)
    end
  end

  describe 'products_count (descendant-inclusive)' do
    let(:electronics) { described_class.create!(name: 'Electronics', store: store) }
    let(:phones) { described_class.create!(name: 'Phones', parent: electronics) }
    let(:laptops) { described_class.create!(name: 'Laptops', parent: electronics) }

    def add(product, category)
      Spree::Categories::AddProducts.call(categories: [category], products: [product])
    end

    it 'counts a directly-assigned product on the category' do
      add(create(:product, store: store), phones)

      expect(phones.reload.products_count).to eq(1)
      expect(phones.classifications.count).to eq(1) # direct
    end

    it 'rolls subcategory products up to ancestors' do
      add(create(:product, store: store), phones)
      add(create(:product, store: store), laptops)

      expect(electronics.reload.products_count).to eq(2) # inclusive
      expect(electronics.classifications.count).to eq(0) # nothing direct
      expect(phones.reload.products_count).to eq(1)
      expect(laptops.reload.products_count).to eq(1)
    end

    it 'de-duplicates a product reachable through several nodes' do
      product = create(:product, store: store)
      add(product, phones)
      add(product, electronics) # also directly on the ancestor

      expect(electronics.reload.products_count).to eq(1) # counted once
    end

    it 'decrements ancestors when a product is removed' do
      product = create(:product, store: store)
      add(product, phones)
      expect(electronics.reload.products_count).to eq(1)

      Spree::Categories::RemoveProducts.call(categories: [phones], products: [product])

      expect(electronics.reload.products_count).to eq(0)
      expect(phones.reload.products_count).to eq(0)
    end

    it 'maintains the count on a direct Classification create/destroy' do
      product = create(:product, store: store)
      classification = create(:product_category, category: phones, product: product)
      expect(electronics.reload.products_count).to eq(1)

      classification.destroy
      expect(electronics.reload.products_count).to eq(0)
    end

    it 'updates both ancestor chains when a subtree moves' do
      other_root = described_class.create!(name: 'Office', store: store)
      add(create(:product, store: store), phones)
      expect(electronics.reload.products_count).to eq(1)

      phones.reload.move_to_child_of(other_root.reload)

      expect(electronics.reload.products_count).to eq(0) # lost the subtree
      expect(other_root.reload.products_count).to eq(1)  # gained it
    end
  end
  let(:store) { @default_store }
  let(:category) { build(:category, name: 'Ruby on Rails', parent: nil) }

  it_behaves_like 'metadata'

  describe '#to_param' do
    it 'is the permalink, so category URLs use the full path' do
      category = create(:category, name: 'Ruby on Rails')

      expect(category.to_param).to eq(category.permalink)
      expect(category.to_param).to eq('ruby-on-rails')
    end
  end


  context 'Scopes' do
    describe '.with_matching_name' do
      let!(:category1) { create(:category, name: 'shoes') }
      let!(:category2) { create(:category, name: 'Premium Shoes') }

      it 'returns the category with the matching name', :aggregate_failures do
        expect(described_class.with_matching_name('SHOES')).to eq([category1])
        expect(described_class.with_matching_name('Shoes')).to eq([category1])
        expect(described_class.with_matching_name('shoes')).to eq([category1])

        expect(described_class.with_matching_name('premium SHOES')).to eq([category2])
        expect(described_class.with_matching_name('Premium shoes')).to eq([category2])
        expect(described_class.with_matching_name('premium shoes')).to eq([category2])
      end

      context 'with translations' do
        before do
          I18n.with_locale(:pl) do
            category1.update!(name: 'Buty')
            category2.update!(name: 'Buty Premium')
          end
        end

        it 'returns the category with the matching name', :aggregate_failures do
          I18n.with_locale(:pl) do
            expect(described_class.with_matching_name('BUTY')).to eq([category1])
            expect(described_class.with_matching_name('Buty')).to eq([category1])
            expect(described_class.with_matching_name('buty')).to eq([category1])

            expect(described_class.with_matching_name('Buty PREMIUM')).to eq([category2])
            expect(described_class.with_matching_name('Buty premium')).to eq([category2])
            expect(described_class.with_matching_name('buty premium')).to eq([category2])
          end
        end
      end
    end
  end

  context 'when using another locale' do
    before do
      root_category = create(:category, name: 'EN parent', store: store)
      category.update!(name: 'EN name', parent: root_category)

      Mobility.with_locale(:pl) do
        root_category.update!(name: 'PL parent')

        category.update!(
          name: 'PL name',
          description: 'PL description'
        )
      end

      category.reload
    end

    let(:category_pl_translation) { category.translations.find_by(locale: 'pl') }

    it 'translates category fields' do
      expect(category.name).to eq('EN name')

      expect(category_pl_translation).to be_present
      expect(category_pl_translation.name).to eq('PL name')
      expect(category_pl_translation.permalink).to eq('pl-parent/pl-name')

      expect(category.description_pl).to eq('PL description')
    end
  end

  context 'set_permalink' do
    it 'sets permalink correctly when no parent present' do
      category.set_permalink
      expect(category.permalink).to eql 'ruby-on-rails'
    end

    it 'supports Chinese characters' do
      category.name = '你好'
      category.set_permalink
      expect(category.permalink).to eql 'ni-hao'
    end

    it 'stores old slugs in FriendlyIds history' do
      # Stub out the unrelated methods that cannot handle a save without an id
      allow(subject).to receive(:set_depth!)
      expect(subject).to receive(:create_slug)
      subject.permalink = 'custom-slug'
      subject.run_callbacks :save
    end

    context 'with parent category' do
      let(:parent) { FactoryBot.build(:category, permalink: 'brands') }

      before       { allow(category).to receive_messages parent: parent }

      it 'sets permalink correctly when category has parent' do
        category.set_permalink
        expect(category.permalink).to eql 'brands/ruby-on-rails'
      end

      it 'sets permalink correctly with existing permalink present' do
        category.permalink = 'b/rubyonrails'
        category.set_permalink
        expect(category.permalink).to eql 'brands/rubyonrails'
      end

      it 'supports Chinese characters' do
        category.name = '我'
        category.set_permalink
        expect(category.permalink).to eql 'brands/wo'
      end

      # Regression test for #3390
      context 'setting a new node sibling position via :child_index=' do
        let(:idx) { rand(0..100) }

        before { allow(parent).to receive(:move_to_child_with_index) }

        context 'category is not new' do
          before { allow(category).to receive(:new_record?).and_return(false) }

          it 'passes the desired index move_to_child_with_index of :parent ' do
            expect(category).to receive(:move_to_child_with_index).with(parent, idx)

            category.child_index = idx
          end
        end
      end
    end
  end

  # Regression test for #13395
  describe 'permalink uniqueness after normalization' do
    let!(:parent) { create(:category, name: 'Parent', store: store) }

    it 'returns a validation error instead of raising RecordNotUnique when normalized permalink conflicts' do
      create(:category, name: 'Foo Bar', parent: parent)

      sibling = create(:category, name: 'Other', parent: parent)
      sibling.permalink = "#{parent.permalink}/Foo Bar"

      expect { sibling.save }.not_to raise_error
      expect(sibling.errors[:permalink]).to be_present
    end

    it 'normalizes permalink before validation on update' do
      category = create(:category, name: 'Test', parent: parent)
      category.permalink = "#{parent.permalink}/Héllo Wörld"
      category.valid?

      expect(category.permalink).to eq("#{parent.permalink}/hello-world")
    end
  end

  # Regression test for #2620
  context 'creating a child node using first_or_create' do
    let!(:parent) { create(:category, name: 'Parent', store: store) }

    it 'does not error out' do
      expect { parent.children.unscoped.where(name: 'Some name', parent_id: parent.id).first_or_create }.not_to raise_error
    end
  end

  context 'ransackable_associations' do
    it { expect(described_class.whitelisted_ransackable_associations).to include('parent') }
    it { expect(described_class.whitelisted_ransackable_associations).not_to include('taxonomy') }
  end

  describe '#cached_self_and_descendants_ids' do
    it { expect(category.cached_self_and_descendants_ids).to eq(category.self_and_descendants.ids) }
  end

  describe '#localized_slugs_for_store' do
    let(:store) { create(:store, default_locale: 'fr', supported_locales: 'en,pl,fr') }
    let!(:root_category) { create(:category, name: 'Categories', store: store) }
    let(:category) { create(:category, permalink: 'test_slug_en', parent: root_category, store: store) }
    let!(:category_translation_fr) { category.translations.create(slug: 'test_slug_fr', locale: 'fr') }

    before { Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) }

    subject { category.localized_slugs_for_store(store) }

    context 'when there are slugs in locales not supported by the store' do
      let!(:category_translation_pl) { category.translations.create(slug: 'test_slug_pl', locale: 'pl') }
      let!(:category_translation_de) { category.translations.create(slug: 'test_slug_de', locale: 'de') }

      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => 'categories/test-slug-pl'
        }
      end

      it 'returns only slugs in locales supported by the store' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when one of the supported locales does not have a translation' do
      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => 'categories/test-slug-fr'
        }
      end

      it "falls back to store's default locale" do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when setting the slug translations for the parent' do
      let!(:root_category_translation_pl) { root_category.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:root_category_translation_fr) { root_category.translations.create(slug: 'categories-fr', locale: 'fr') }

      let(:expected_slugs) do
        {
          'en' => 'categories',
          'fr' => 'categories-fr',
          'pl' => 'slug-with-space'
        }
      end

      it "sets the slugs in slug format" do
        expect(root_category.reload.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end

    context 'when setting the slugs in category under taxomony with different parent slug' do
      let!(:root_category_translation_pl) { root_category.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:category_translation_pl) { category.translations.create(locale: 'pl') }

      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => "slug-with-space/#{category.name.to_url}"
        }
      end

      it "sets the slug in valid format" do
        expect(category.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end
  end

  describe '#regenerate_pretty_name_and_permalink' do
    let!(:parent) { create(:category, name: 'Parent', store: store) }
    let!(:category) { create(:category, name: 'Category#1', parent: parent, store: store) }

    it 'regenerates pretty name and permalink' do
      expect(category.pretty_name).to eq("#{category.parent.pretty_name} -> #{category.name}")
      expect(category.permalink).to eq("#{category.parent.permalink}/#{category.name.to_url}")
    end

    context "when parent's permalink is changed" do
      before do
        category.parent.update!(permalink: 'new-permalink')
      end

      it 'updates the pretty name and permalink' do
        expect(category.reload.pretty_name).to eq("#{category.parent.pretty_name} -> #{category.name}")
        expect(category.permalink).to eq("new-permalink/#{category.name.to_url}")
      end
    end

    context 'when parent name is changed' do
      before do
        category.parent.update!(name: 'New Parent')
      end

      it 'updates the pretty name and permalink' do
        expect(category.reload.pretty_name).to eq("New Parent -> #{category.name}")
        expect(category.permalink).to eq("#{category.parent.permalink}/#{category.name.to_url}")
      end
    end

    context 'with translations' do
      before do
        Mobility.with_locale(:pl) do
          category.update!(name: 'Kategoria#1')
          category.reload

          category.parent.update!(name: 'Kategoria')
        end
      end

      it 'updates the pretty name and permalink for translations as well' do
        Mobility.with_locale(:pl) do
          expect(category.reload.pretty_name).to eq('Kategoria -> Kategoria#1')
          expect(category.permalink).to eq('kategoria/kategoria-number-1')
        end
      end
    end

    context 'when category is moved' do
      let(:parent2) { create(:category, name: 'Parent2', permalink: 'parent2', parent: parent) }
      let(:category2) { create(:category, name: 'Child', parent: parent2, permalink: 'child') }

      before do
        category.parent.update!(name: 'Grandparent', permalink: 'grandparent')
        category.update!(name: 'Parent', permalink: 'parent')

        parent2
        category2

        Mobility.with_locale(:pl) do
          category.parent.update!(name: 'Dziadek', permalink: 'dziadek')
          category.update!(name: 'Rodzic')

          parent2.update!(name: 'Rodzic2', permalink: 'rodzic2')
          category2.update!(name: 'Dziecko')
        end

        expect(category.permalink).to eq('grandparent/parent')
        expect(category.pretty_name).to eq('Grandparent -> Parent')

        expect(category2.permalink).to eq('grandparent/parent2/child')
        expect(category2.pretty_name).to eq('Grandparent -> Parent2 -> Child')

        Mobility.with_locale(:pl) do
          expect(category.reload.pretty_name).to eq('Dziadek -> Rodzic')
          expect(category.permalink).to eq('dziadek/rodzic')

          expect(category2.pretty_name).to eq('Dziadek -> Rodzic2 -> Dziecko')
          expect(category2.permalink).to eq('dziadek/rodzic2/dziecko')
        end
      end

      it 'updates the pretty name and permalink' do
        category2.move_to_child_with_index(category, 0)

        expect(category2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')
        expect(category2.permalink).to eq('grandparent/parent/child')

        Mobility.with_locale(:pl) do
          expect(category2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(category2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end

      it 'updates the pretty name and permalink when move is done inside different locales' do
        Mobility.with_locale(:pl) do
          category2.move_to_child_with_index(category, 0)
        end

        expect(category2.permalink).to eq('grandparent/parent/child')
        expect(category2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')

        Mobility.with_locale(:pl) do
          expect(category2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(category2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end
    end
  end

  describe '#pretty_name' do
    let!(:category) { create(:category, name: 'Category#1') }

    context 'top level' do
      it 'is just the category name' do
        expect(category.pretty_name).to eq(category.name)
      end
    end

    context '2+ lvl deep' do
      let(:category_parent) { create(:category, name: 'Parent') }

      before do
        category.parent = category_parent
        category.save!
      end

      it 'returns parent name and category name' do
        expect(category.reload.pretty_name).to eq('Parent -> Category#1')
      end

      context 'when name is updated' do
        before do
          category.name = 'New Name'
          category.save!
        end

        it 'returns the updated pretty name' do
          expect(category.reload.pretty_name).to eq('Parent -> New Name')
        end
      end

      context 'when parent name is updated' do
        before do
          category_parent.name = 'New Parent'
          category_parent.save!
        end

        it 'returns the updated pretty name' do
          expect(category.reload.pretty_name).to eq('New Parent -> Category#1')
        end
      end
    end

    context 'when `always_use_translations` is disabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(false)
      end

      it 'sets the pretty name' do
        expect(category.reload.pretty_name).to eq(category.name)
      end
    end

    context 'when `always_use_translations` is enabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(true)
      end

      it 'sets the pretty name' do
        expect(category.reload.pretty_name).to eq(category.name)
      end
    end
  end

  describe '#active_products_with_descendants' do
    let(:root_category) { create(:category) }

    context 'when category has products' do
      let!(:product) { create(:product, categories: [root_category]) }

      it 'returns true' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be true
      end

      it 'returns true when products aren\'t active' do
        product.update(status: 'draft')

        expect(root_category.reload.products.exists?).to be true
      end
    end

    context 'when only children categories have products' do
      let(:parent_category) { create(:category, parent: root_category) }
      let(:child_category) { create(:category, parent: parent_category) }
      let!(:product) { create(:product, categories: [child_category]) }

      it 'returns true' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be true
      end

      it 'returns false when products aren\'t active' do
        product.update(status: 'draft')

        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end

    context 'when category has no products' do
      it 'returns false' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end

    context 'when category has products but children categories have no products' do
      let(:parent_category) { create(:category, parent: root_category) }
      let!(:child_category) { create(:category, parent: parent_category) }
      let!(:product) { create(:product, categories: [root_category]) }

      it 'returns true' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be true
      end

      it 'returns false when products aren\'t active' do
        product.update(status: 'draft')

        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end

    context 'when children categories also have no products' do
      let(:parent_category) { create(:category, parent: root_category) }
      let!(:child_category) { create(:category, parent: parent_category) }

      it 'returns false' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end
  end

  # acts_as_nested_set is scoped by store, so each store owns an independent
  # tree rather than sharing one global lft/rgt sequence.
  describe 'per-store nested set' do
    let(:other_store) { create(:store) }

    it 'numbers each store from the start instead of continuing the previous one' do
      create(:category, name: 'A', store: store)
      other_root = create(:category, name: 'B', store: other_store)

      expect(other_root.reload.lft).to eq(1)
    end

    it 'leaves another store untouched when a tree is reordered' do
      first = create(:category, name: 'A1', store: store)
      create(:category, name: 'A2', store: store)
      other_root = create(:category, name: 'B1', store: other_store)
      create(:category, name: 'B2', parent: other_root, store: other_store)

      before_bounds = described_class.unscoped.where(store: other_store).order(:id).pluck(:lft, :rgt)
      first.reload.move_to_root
      after_bounds = described_class.unscoped.where(store: other_store).order(:id).pluck(:lft, :rgt)

      expect(after_bounds).to eq(before_bounds)
    end

    it 'keeps subtree reads inside the owning store' do
      root = create(:category, name: 'Root', store: store)
      child = create(:category, name: 'Child', parent: root, store: store)
      create(:category, name: 'Foreign', store: other_store)

      expect(root.reload.self_and_descendants).to contain_exactly(root, child)
    end
  end
end
