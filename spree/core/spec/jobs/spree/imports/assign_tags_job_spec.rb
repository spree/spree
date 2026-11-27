require 'spec_helper'

RSpec.describe Spree::Imports::AssignTagsJob, type: :job do
  let(:store) { @default_store }
  let!(:product) { create(:product) }

  describe '#perform' do
    it 'assigns tags to the product' do
      described_class.perform_now(product.id, 'ECO, Gold')

      expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
    end

    it 'ignores blank tag names' do
      described_class.perform_now(product.id, 'ECO,, Gold, ')

      expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
    end

    it 'keeps a quoted tag containing the delimiter whole' do
      described_class.perform_now(product.id, '"Red,Blue", Gold')

      expect(product.reload.tag_list).to contain_exactly('Red,Blue', 'Gold')
    end

    context "when the store's default locale differs from I18n.default_locale" do
      let(:german_store) { create(:store).tap { |s| s.default_market.update!(default_locale: 'de', supported_locales: 'de,en') }.reload }
      let!(:product) do
        # Imported in the store's locale, so the name lives in the base column.
        Spree::Current.with_content_locale('de') { I18n.with_locale(:de) { create(:product, name: 'Hemd', store: german_store) } }
      end

      it 'reads the product in the store locale and saves its tags' do
        # The job wrapper reset Spree::Current; I18n still names the store's locale.
        I18n.with_locale(:de) do
          expect { described_class.perform_now(product.id, 'ECO, Gold') }.not_to raise_error
        end

        expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
        expect(product.read_attribute(:name)).to eq('Hemd')
      end
    end

    it 'replaces existing tags' do
      product.tag_list = 'Old Tag'
      product.save!

      described_class.perform_now(product.id, 'New Tag')

      expect(product.reload.tag_list).to contain_exactly('New Tag')
    end

    it 'is idempotent' do
      described_class.perform_now(product.id, 'ECO, Gold')
      described_class.perform_now(product.id, 'ECO, Gold')

      expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
    end

    context 'when there were no matching tags' do
      it 'creates the tags' do
        expect {
          described_class.perform_now(product.id, 'ECO, Gold')
        }.to change { ActsAsTaggableOn::Tag.count }.by(2)
      end
    end

    context 'when there were matching tags' do
      before do
        ActsAsTaggableOn::Tag.create(name: 'ECO')
        ActsAsTaggableOn::Tag.create(name: 'Gold')
      end

      it 'does not create new tags' do
        expect {
          described_class.perform_now(product.id, 'ECO, Gold')
        }.not_to change { ActsAsTaggableOn::Tag.count }
      end
    end
  end
end
