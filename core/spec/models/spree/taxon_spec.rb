require 'spec_helper'

describe Spree::Taxon, type: :model do
  let(:store) { @default_store }
  let(:taxonomy) { store.taxonomies.first }
  let(:taxon) { build(:taxon, name: 'Ruby on Rails', parent: nil) }

  it_behaves_like 'metadata'

  describe '#to_param' do
    subject { super().to_param }

    it { is_expected.to eql taxon.permalink }
  end

  context 'Validations' do
    describe '#check_for_root' do
      let(:valid_taxon) { build(:taxon, name: 'Vaild Rails', parent_id: taxonomy.root.id, taxonomy: taxonomy) }

      it 'does not validate the taxon' do
        expect(taxon.valid?).to eq false
      end

      it 'validates the taxon' do
        expect(valid_taxon.valid?).to eq true
      end
    end

    describe '#parent_belongs_to_same_taxonomy' do
      let(:valid_parent) { create(:taxon, name: 'Valid Parent', taxonomy: taxonomy) }
      let(:invalid_parent) { create(:taxon, name: 'Invalid Parent', taxonomy: create(:taxonomy, store: store)) }

      it 'does not validate the taxon' do
        expect(build(:taxon, taxonomy: taxonomy, parent: invalid_parent).valid?).to eq false
      end

      it 'validates the taxon' do
        expect(build(:taxon, taxonomy: taxonomy, parent: valid_parent).valid?).to eq true
      end
    end
  end

  context 'Scopes' do
    describe '.for_taxonomy' do
      let!(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') || create(:taxonomy, name: 'Categories') }
      let!(:root_category) { create(:taxon, taxonomy: categories_taxonomy) }

      context 'when translations are disabled' do
        it 'returns the correct taxon' do
          expect(described_class.for_taxonomy('Categories')).to contain_exactly(
            root_category,
            root_category.parent
          )
        end
      end

      context 'when translations are enabled' do
        before do
          taxonomy

          Spree::Config.always_use_translations = true
          I18n.locale = :de

          categories_taxonomy.name = "Kategorien"
          categories_taxonomy.save!
        end

        after do
          Spree::Config.always_use_translations = false
          I18n.locale = :en
        end

        it 'returns the correct taxon' do
          expect(described_class.for_taxonomy('Kategorien')).to contain_exactly(
            root_category,
            root_category.parent
          )
        end
      end
    end

    describe '.with_matching_name' do
      let!(:taxon1) { create(:taxon, name: 'shoes', taxonomy: taxonomy) }
      let!(:taxon2) { create(:taxon, name: 'Premium Shoes', taxonomy: taxonomy) }

      it 'returns the taxon with the matching name', :aggregate_failures do
        expect(described_class.with_matching_name('SHOES')).to eq([taxon1])
        expect(described_class.with_matching_name('Shoes')).to eq([taxon1])
        expect(described_class.with_matching_name('shoes')).to eq([taxon1])

        expect(described_class.with_matching_name('premium SHOES')).to eq([taxon2])
        expect(described_class.with_matching_name('Premium shoes')).to eq([taxon2])
        expect(described_class.with_matching_name('premium shoes')).to eq([taxon2])
      end

      context 'with translations' do
        before do
          I18n.with_locale(:pl) do
            taxon1.update!(name: 'Buty')
            taxon2.update!(name: 'Buty Premium')
          end
        end

        it 'returns the taxon with the matching name', :aggregate_failures do
          I18n.with_locale(:pl) do
            expect(described_class.with_matching_name('BUTY')).to eq([taxon1])
            expect(described_class.with_matching_name('Buty')).to eq([taxon1])
            expect(described_class.with_matching_name('buty')).to eq([taxon1])

            expect(described_class.with_matching_name('Buty PREMIUM')).to eq([taxon2])
            expect(described_class.with_matching_name('Buty premium')).to eq([taxon2])
            expect(described_class.with_matching_name('buty premium')).to eq([taxon2])
          end
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'regenerate_taxon_products' do
      let!(:taxon) { create(:automatic_taxon) }

      before { taxon.reload }

      context "when taxon's rules_match_policy changes" do
        it 'calls #regenerate_taxon_products' do
          expect(taxon).to receive(:regenerate_taxon_products).and_call_original

          taxon.update!(rules_match_policy: :any)
        end
      end

      context 'when taxon\'s rule changes' do
        let!(:tag_rule) { create(:tag_taxon_rule, taxon: taxon, value: 'tag') }

        it 'calls #regenerate_taxon_products' do
          tag_rule.reload
          expect(tag_rule).to receive(:regenerate_taxon_products).and_call_original

          tag_rule.update!(value: 'new tag')
        end
      end

      context 'when rule is destroyed' do
        let!(:tag_rule) { create(:tag_taxon_rule, taxon: taxon, value: 'tag') }

        it 'calls #regenerate_taxon_products' do
          tag_rule.reload
          expect(tag_rule).to receive(:regenerate_taxon_products).and_call_original

          tag_rule.destroy!
        end
      end

      context 'when rule is created' do
        it 'calls #regenerate_taxon_products' do
          expect(taxon).to receive(:regenerate_taxon_products).and_call_original

          create(:tag_taxon_rule, taxon: taxon, value: 'tag')
        end
      end
    end

    describe 'after_destroy :remove_all_featured_sections' do
      let(:taxon) { create(:taxon) }
      let!(:featured_section) { create(:featured_taxon_page_section, preferred_taxon_id: taxon.id) }

      it 'removes the associated featured section' do
        expect { taxon.destroy! }.to change(Spree::PageSections::FeaturedTaxon, :count).from(3).to(2)
        expect(featured_section.reload).to be_deleted
      end
    end
  end

  context 'when using another locale' do
    before do
      root_taxon = taxon.taxonomy.root
      taxon.update!(name: 'EN name', parent: taxon.taxonomy.root)

      Mobility.with_locale(:pl) do
        root_taxon.update!(name: 'PL taxonomy')

        taxon.update!(
          name: 'PL name',
          description: 'PL description'
        )
      end

      taxon.reload
    end

    let(:taxon_pl_translation) { taxon.translations.find_by(locale: 'pl') }

    it 'translates taxon fields' do
      expect(taxon.name).to eq('EN name')

      expect(taxon_pl_translation).to be_present
      expect(taxon_pl_translation.name).to eq('PL name')
      expect(taxon_pl_translation.permalink).to eq('pl-taxonomy/pl-name')

      expect(taxon.description_pl.to_plain_text).to eq('PL description')
    end
  end

  context 'set_permalink' do
    it 'sets permalink correctly when no parent present' do
      taxon.set_permalink
      expect(taxon.permalink).to eql 'ruby-on-rails'
    end

    it 'supports Chinese characters' do
      taxon.name = '你好'
      taxon.set_permalink
      expect(taxon.permalink).to eql 'ni-hao'
    end

    it 'stores old slugs in FriendlyIds history' do
      # Stub out the unrelated methods that cannot handle a save without an id
      allow(subject).to receive(:set_depth!)
      expect(subject).to receive(:create_slug)
      subject.permalink = 'custom-slug'
      subject.run_callbacks :save
    end

    context 'with parent taxon' do
      let(:parent) { FactoryBot.build(:taxon, permalink: 'brands') }

      before       { allow(taxon).to receive_messages parent: parent }

      it 'sets permalink correctly when taxon has parent' do
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/ruby-on-rails'
      end

      it 'sets permalink correctly with existing permalink present' do
        taxon.permalink = 'b/rubyonrails'
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/rubyonrails'
      end

      it 'supports Chinese characters' do
        taxon.name = '我'
        taxon.set_permalink
        expect(taxon.permalink).to eql 'brands/wo'
      end

      # Regression test for #3390
      context 'setting a new node sibling position via :child_index=' do
        let(:idx) { rand(0..100) }

        before { allow(parent).to receive(:move_to_child_with_index) }

        context 'taxon is not new' do
          before { allow(taxon).to receive(:new_record?).and_return(false) }

          it 'passes the desired index move_to_child_with_index of :parent ' do
            expect(taxon).to receive(:move_to_child_with_index).with(parent, idx)

            taxon.child_index = idx
          end
        end
      end
    end
  end

  # Regression test for #2620
  context 'creating a child node using first_or_create' do
    let!(:taxonomy) { create(:taxonomy, store: store) }

    it 'does not error out' do
      expect { taxonomy.root.children.unscoped.where(name: 'Some name', parent_id: taxonomy.taxons.first.id).first_or_create }.not_to raise_error
    end
  end

  context 'ransackable_associations' do
    it { expect(described_class.whitelisted_ransackable_associations).to include('taxonomy') }
  end

  describe '#cached_self_and_descendants_ids' do
    it { expect(taxon.cached_self_and_descendants_ids).to eq(taxon.self_and_descendants.ids) }
  end

  describe '#copy_taxonomy_from_parent' do
    let!(:parent) { create(:taxon, taxonomy: taxonomy) }
    let(:taxon) { build(:taxon, parent: parent, taxonomy: nil) }

    it { expect(taxon.valid?).to eq(true) }
    it { expect { taxon.save! }.to change(taxon, :taxonomy).to(taxonomy) }
  end

  describe '#sync_taxonomy_name' do
    let!(:taxonomy) { create(:taxonomy, name: 'Soft Goods', store: store) }
    let!(:taxon) { create(:taxon, taxonomy: taxonomy, name: 'Socks' ) }

    context 'when none root taxon name is updated' do
      it 'does not update the taxonomy name' do
        taxon.update!(name: 'Shoes')
        taxonomy.reload

        expect(taxonomy.name).not_to eql taxon.name
        expect(taxonomy.name).to eql 'Soft Goods'
      end
    end

    context 'when root taxon name is updated' do
      it 'updates the taxonomy name' do
        root_taxon = described_class.find_by(name: 'Soft Goods')

        root_taxon.update!(name: 'Hard Goods')
        taxonomy.reload

        expect(taxonomy.name).not_to eql 'Soft Goods'
        expect(taxonomy.name).to eql root_taxon.name
      end
    end

    context 'when root taxon name is updated with special characters' do
      it 'updates the taxonomy name' do
        root_taxon = described_class.find_by(name: 'Soft Goods')

        root_taxon.update!(name: 'spÉcial Numérique ƒ ˙ ¨ πø∆©')
        taxonomy.reload

        expect(taxonomy.name).not_to eql 'Soft Goods'
        expect(taxonomy.name).to eql root_taxon.name
      end
    end

    context 'when root taxon attribute other than name is updated' do
      it 'does not update the taxonomy' do
        root_taxon = described_class.find_by(name: 'Soft Goods')
        taxonomy_updated_at = taxonomy.updated_at.to_s

        expect {
          root_taxon.update!(permalink: 'something-else')
          root_taxon.reload
          taxonomy.reload
        }.not_to change { taxonomy.updated_at.to_s }.from(taxonomy_updated_at)

        expect(root_taxon.permalink).to eql 'something-else'
      end
    end
  end

  describe '#localized_slugs_for_store' do
    let(:store) { create(:store, default_locale: 'fr', supported_locales: 'en,pl,fr') }
    let(:taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_categories_name)) }
    let(:taxon) { create(:taxon, taxonomy: taxonomy, permalink: 'test_slug_en') }
    let!(:taxon_translation_fr) { taxon.translations.create(slug: 'test_slug_fr', locale: 'fr') }
    let!(:root_taxon) { taxonomy.taxons.find_by(parent_id: nil) }

    before { Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) }

    subject { taxon.localized_slugs_for_store(store) }

    context 'when there are slugs in locales not supported by the store' do
      let!(:taxon_translation_pl) { taxon.translations.create(slug: 'test_slug_pl', locale: 'pl') }
      let!(:taxon_translation_de) { taxon.translations.create(slug: 'test_slug_de', locale: 'de') }

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

    context 'when setting the slug translations for taxonomy' do
      let!(:root_taxon_translation_pl) { root_taxon.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:root_taxon_translation_fr) { root_taxon.translations.create(slug: 'categories-fr', locale: 'fr') }

      let(:expected_slugs) do
        {
          'en' => 'categories',
          'fr' => 'categories-fr',
          'pl' => 'slug-with-space'
        }
      end

      it "sets the slugs in slug format" do
        expect(root_taxon.reload.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end

    context 'when setting the slugs in taxon under taxomony with different parent slug' do
      let!(:root_taxon_translation_pl) { root_taxon.translations.create(slug: 'slug with space', locale: 'pl') }
      let!(:taxon_translation_pl) { taxon.translations.create(locale: 'pl') }

      let(:expected_slugs) do
        {
          'en' => 'categories/test-slug-en',
          'fr' => 'categories/test-slug-fr',
          'pl' => "slug-with-space/#{taxon.name.to_url}"
        }
      end

      it "sets the slug in valid format" do
        expect(taxon.localized_slugs_for_store(store)).to match(expected_slugs)
      end
    end
  end

  describe '#regenerate_pretty_name_and_permalink' do
    let!(:taxon) { create(:taxon, name: 'Category#1', taxonomy: taxonomy) }

    it 'regenerates pretty name and permalink' do
      expect(taxon.pretty_name).to eq("#{taxon.parent.pretty_name} -> #{taxon.name}")
      expect(taxon.permalink).to eq("#{taxon.parent.permalink}/#{taxon.name.to_url}")
    end

    context "when parent's permalink is changed" do
      before do
        taxon.parent.update!(permalink: 'new-permalink')
      end

      it 'updates the pretty name and permalink' do
        expect(taxon.reload.pretty_name).to eq("#{taxon.parent.pretty_name} -> #{taxon.name}")
        expect(taxon.permalink).to eq("new-permalink/#{taxon.name.to_url}")
      end
    end

    context 'when parent name is changed' do
      before do
        taxon.parent.update!(name: 'New Parent')
      end

      it 'updates the pretty name and permalink' do
        expect(taxon.reload.pretty_name).to eq("New Parent -> #{taxon.name}")
        expect(taxon.permalink).to eq("#{taxon.parent.permalink}/#{taxon.name.to_url}")
      end
    end

    context 'with translations' do
      before do
        Mobility.with_locale(:pl) do
          taxon.update!(name: 'Kategoria#1')
          taxon.reload

          taxon.parent.update!(name: 'Kategoria')
        end
      end

      it 'updates the pretty name and permalink for translations as well' do
        Mobility.with_locale(:pl) do
          expect(taxon.reload.pretty_name).to eq('Kategoria -> Kategoria#1')
          expect(taxon.permalink).to eq('kategoria/kategoria-number-1')
        end
      end
    end

    context 'when taxon is moved' do
      let(:parent2) { create(:taxon, name: 'Parent2', permalink: 'parent2', taxonomy: taxonomy) }
      let(:taxon2) { create(:taxon, name: 'Child', parent: parent2, permalink: 'child', taxonomy: taxonomy) }

      before do
        taxon.parent.update!(name: 'Grandparent', permalink: 'grandparent')
        taxon.update!(name: 'Parent', permalink: 'parent')

        parent2
        taxon2

        Mobility.with_locale(:pl) do
          taxon.parent.update!(name: 'Dziadek', permalink: 'dziadek')
          taxon.update!(name: 'Rodzic')

          parent2.update!(name: 'Rodzic2', permalink: 'rodzic2')
          taxon2.update!(name: 'Dziecko')
        end

        expect(taxon.permalink).to eq('grandparent/parent')
        expect(taxon.pretty_name).to eq('Grandparent -> Parent')

        expect(taxon2.permalink).to eq('grandparent/parent2/child')
        expect(taxon2.pretty_name).to eq('Grandparent -> Parent2 -> Child')

        Mobility.with_locale(:pl) do
          expect(taxon.reload.pretty_name).to eq('Dziadek -> Rodzic')
          expect(taxon.permalink).to eq('dziadek/rodzic')

          expect(taxon2.pretty_name).to eq('Dziadek -> Rodzic2 -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic2/dziecko')
        end
      end

      it 'updates the pretty name and permalink' do
        taxon2.move_to_child_with_index(taxon, 0)

        expect(taxon2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')
        expect(taxon2.permalink).to eq('grandparent/parent/child')

        Mobility.with_locale(:pl) do
          expect(taxon2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end

      it 'updates the pretty name and permalink when move is done inside different locales' do
        Mobility.with_locale(:pl) do
          taxon2.move_to_child_with_index(taxon, 0)
        end

        expect(taxon2.permalink).to eq('grandparent/parent/child')
        expect(taxon2.reload.pretty_name).to eq('Grandparent -> Parent -> Child')

        Mobility.with_locale(:pl) do
          expect(taxon2.reload.pretty_name).to eq('Dziadek -> Rodzic -> Dziecko')
          expect(taxon2.permalink).to eq('dziadek/rodzic/dziecko')
        end
      end
    end
  end

  describe '#pretty_name' do
    let!(:taxon) { create(:taxon, name: 'Category#1', taxonomy: taxonomy) }

    context '1 lvl deep' do
      it 'returns taxonomy name and taxon name' do
        expect(taxon.pretty_name).to eq("#{taxonomy.root.pretty_name} -> #{taxon.name}")
      end
    end

    context '2+ lvl deep' do
      let(:taxon_parent) { create(:taxon, name: 'Parent', taxonomy: taxonomy) }

      before do
        taxon.parent = taxon_parent
        taxon.save!
      end

      it 'returns parent name and taxon name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> Parent -> Category#1")
      end

      context 'when name is updated' do
        before do
          taxon.name = 'New Name'
          taxon.save!
        end

        it 'returns the updated pretty name' do
          expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> Parent -> New Name")
        end
      end

      context 'when parent name is updated' do
        before do
          taxon_parent.name = 'New Parent'
          taxon_parent.save!
        end

        it 'returns the updated pretty name' do
          expect(taxon.reload.pretty_name).to eq("#{taxonomy.root.pretty_name} -> New Parent -> Category#1")
        end
      end
    end

    context 'when `always_use_translations` is disabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(false)
      end

      it 'sets the pretty name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.name} -> #{taxon.name}")
      end
    end

    context 'when `always_use_translations` is enabled' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(true)
      end

      it 'sets the pretty name' do
        expect(taxon.reload.pretty_name).to eq("#{taxonomy.name} -> #{taxon.name}")
      end
    end
  end

  describe '#store' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:taxon) { build(:taxon, taxonomy: taxonomy) }

    it 'returns the store from the taxonomy' do
      expect(taxon.store).to eq(store)
    end
  end

  describe '#active_products_with_descendants' do
    let(:root_category) { create(:taxon, taxonomy: taxonomy) }

    context 'when category has products' do
      let!(:product) { create(:product, taxons: [root_category]) }

      it 'returns true' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be true
      end

      it 'returns true when products aren\'t active' do
        product.update(status: 'draft')

        expect(root_category.reload.products.exists?).to be true
      end
    end

    context 'when only children categories have products' do
      let(:parent_category) { create(:taxon, taxonomy: taxonomy, parent: root_category) }
      let(:child_category) { create(:taxon, taxonomy: taxonomy, parent: parent_category) }
      let!(:product) { create(:product, taxons: [child_category]) }

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
      let(:parent_category) { create(:taxon, taxonomy: taxonomy, parent: root_category) }
      let!(:child_category) { create(:taxon, taxonomy: taxonomy, parent: parent_category) }
      let!(:product) { create(:product, taxons: [root_category]) }

      it 'returns true' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be true
      end

      it 'returns false when products aren\'t active' do
        product.update(status: 'draft')

        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end

    context 'when children categories also have no products' do
      let(:parent_category) { create(:taxon, taxonomy: taxonomy, parent: root_category) }
      let!(:child_category) { create(:taxon, taxonomy: taxonomy, parent: parent_category) }

      it 'returns false' do
        expect(root_category.reload.active_products_with_descendants.exists?).to be false
      end
    end
  end

  describe '#products_matching_rules' do
    context 'when the taxon is manual' do
      let(:taxon) { create(:taxon) }

      it 'returns an empty taxon' do
        expect(taxon.reload.products_matching_rules).to be_empty
      end
    end

    context 'when the taxon is automatic' do
      let(:taxon) { create(:automatic_taxon) }

      context 'when the taxon has no rules' do
        it 'returns an empty taxon' do
          expect(taxon.reload.products_matching_rules).to be_empty
        end
      end

      context 'when the taxon has rules' do
        context 'when the rule is a tag rule' do
          let(:cruelty_free_tag) { ActsAsTaggableOn::Tag.create(name: 'cruelty-free') }
          let(:discounted_tag) { ActsAsTaggableOn::Tag.create(name: 'discounted') }
          let(:other_tag) { ActsAsTaggableOn::Tag.create(name: 'other') }
          let!(:cruelty_free_product) { create(:product, tags: [cruelty_free_tag]) }
          let!(:discounted_product) { create(:product, tags: [discounted_tag]) }
          let!(:both_tags_product) { create(:product, tags: [cruelty_free_tag, discounted_tag]) }
          let!(:other_product) { create(:product, tags: [other_tag]) }

          context 'when the match policy is is_equal_to' do
            it 'returns products that match cruelty-free tag' do
              create(:tag_taxon_rule, taxon: taxon, value: cruelty_free_tag.name)

              expect(taxon.reload.products_matching_rules).to contain_exactly(cruelty_free_product, both_tags_product)
            end

            it 'returns products that match discounted tag' do
              create(:tag_taxon_rule, taxon: taxon, value: discounted_tag.name)

              expect(taxon.reload.products_matching_rules).to contain_exactly(discounted_product, both_tags_product)
            end

            context 'with all rules match policy' do
              it 'returns products that match both tags' do
                create(:tag_taxon_rule, taxon: taxon, value: cruelty_free_tag.name)
                create(:tag_taxon_rule, taxon: taxon, value: discounted_tag.name)

                expect(taxon.reload.products_matching_rules).to contain_exactly(both_tags_product)
              end
            end

            context 'with any rules match policy' do
              let(:taxon) { create(:automatic_taxon, :any_match_policy) }

              it 'returns products that match any tag' do
                create(:tag_taxon_rule, taxon: taxon, value: cruelty_free_tag.name)
                create(:tag_taxon_rule, taxon: taxon, value: discounted_tag.name)

                expect(taxon.reload.products_matching_rules).to contain_exactly(cruelty_free_product, discounted_product, both_tags_product)
              end
            end
          end

          context 'when the match policy is is_not_equal_to' do
            it 'returns products that do not match cruelty-free tag' do
              create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: cruelty_free_tag.name)

              expect(taxon.reload.products_matching_rules).to contain_exactly(discounted_product, other_product)
            end

            it 'returns products that do not match discounted tag' do
              create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: discounted_tag.name)

              expect(taxon.reload.products_matching_rules).to contain_exactly(cruelty_free_product, other_product)
            end

            context 'with all rules match policy' do
              it 'returns products that do not match both tags' do
                create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: cruelty_free_tag.name)
                create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: discounted_tag.name)

                expect(taxon.reload.products_matching_rules).to contain_exactly(other_product)
              end
            end

            context 'with any rules match policy' do
              let(:taxon) { create(:automatic_taxon, :any_match_policy) }

              it 'returns products that do not match any tag' do
                create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: cruelty_free_tag.name)
                create(:tag_taxon_rule, :is_not_equal_to, taxon: taxon, value: discounted_tag.name)

                expect(taxon.reload.products_matching_rules).to contain_exactly(cruelty_free_product, discounted_product, other_product)
              end
            end
          end
        end

        context 'when the rule is a sale rule' do
          let!(:product_with_master_on_sale) { create(:product, price: 10, compare_at_price: 12) }
          let!(:product_with_one_variant_on_sale) do
            create(:product).tap do |p|
              create(:variant, product: p, price: 10, compare_at_price: 12)
              create(:variant, product: p, price: 10)
            end
          end
          let!(:product_on_sale_with_different_currency) do
            create(:product, price: 10).tap do |p|
              p.master.prices.create(amount: 10, compare_at_amount: 12, currency: 'PLN')
            end
          end
          let!(:product_not_on_sale) { create(:product, price: 10) }

          context 'when the match policy is is_equal_to' do
            it 'matches products that are on sale in store\'s currency' do
              create(:sale_taxon_rule, taxon: taxon)

              expect(taxon.reload.products_matching_rules).to contain_exactly(product_with_master_on_sale, product_with_one_variant_on_sale)
            end
          end

          context 'when the match policy is in_not_equal_to' do
            it 'matches products that aren\'t on sale and have price in store\'s currency' do
              create(:sale_taxon_rule, :is_not_equal_to, taxon: taxon)

              expect(taxon.reload.products_matching_rules).to contain_exactly(product_not_on_sale, product_on_sale_with_different_currency)
            end
          end
        end
      end
    end
  end

  describe '#featured?' do
    subject { taxon.featured? }

    let(:taxon) { create(:taxon) }
    let!(:featured_section) { create(:featured_taxon_page_section, preferred_taxon_id: featured_taxon.id) }

    context 'with a featured section' do
      let(:featured_taxon) { taxon }

      it { is_expected.to be(true) }
    end

    context 'with no featured section' do
      let(:featured_taxon) { create(:taxon) }

      it { is_expected.to be(false) }
    end
  end

  describe '#page_builder_image' do
    subject(:page_builder_image) { taxon.page_builder_image }

    let(:taxon) { build(:taxon, image: image, square_image: square_image) }

    context 'when image and square image are not attached' do
      let(:image) { nil }
      let(:square_image) { nil }

      it { is_expected.to_not be_attached }
    end

    context 'when only image is attached' do
      let(:image) { file_fixture('icon_256x256.png') }
      let(:square_image) { nil }

      it { is_expected.to be_attached }
      it { is_expected.to eq(taxon.image)}
    end

    context 'when both image and square image are attached' do
      let(:image) { file_fixture('icon_256x256.png') }
      let(:square_image) { file_fixture('icon_256x256.png') }

      it { is_expected.to be_attached}
      it { is_expected.to eq(taxon.square_image)}
    end
  end

  describe '#featured_sections' do
    subject { taxon.featured_sections }

    let(:taxon) { create(:taxon) }

    let!(:featured_sections) { create_list(:featured_taxon_page_section, 2, preferred_taxon_id: featured_taxon.id) }
    let!(:other_featured_sections) { create_list(:featured_taxon_page_section, 2, preferred_taxon_id: create(:taxon).id) }

    context 'with featured sections' do
      let(:featured_taxon) { taxon }

      it { is_expected.to contain_exactly(*featured_sections) }
    end

    context 'with no featured sections' do
      let(:featured_taxon) { create(:taxon) }

      it { is_expected.to be_empty }
    end
  end
end
