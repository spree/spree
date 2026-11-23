require 'spec_helper'

RSpec.describe Spree::Imports::AssignTagsJob, type: :job do
  let(:store) { @default_store }
  let!(:product) { create(:product) }

  describe '#perform' do
    it 'assigns tags to the product' do
      described_class.perform_now(product.id, 'ECO, Gold')

      expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
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

    context "when the store's default locale differs from I18n.default_locale" do
      let!(:product) { create(:product, name: 'Kaffeemühle', store: store) }

      before { store.update_columns(default_locale: 'de') }

      it 'reads the base-column name in the store locale and saves the tags' do
        # The enqueue-time locale a German store's import captures into the
        # job; the content locale is not carried over with it.
        I18n.with_locale(:de) do
          expect { described_class.perform_now(product.id, 'ECO, Gold') }.not_to raise_error
        end

        expect(product.reload.tag_list).to contain_exactly('ECO', 'Gold')
      end

      it 'restores the content locale afterwards' do
        I18n.with_locale(:de) { described_class.perform_now(product.id, 'ECO') }

        expect(Spree::Current.content_locale).to eq(I18n.default_locale.to_s)
      end
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
