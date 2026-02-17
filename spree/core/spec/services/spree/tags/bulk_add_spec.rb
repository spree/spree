require 'spec_helper'

module Spree
  describe Tags::BulkAdd do
    let(:tag_names) { ['tag1', 'tag2', 'tag3'] }
    let(:products) { create_list(:product, 3) }
    let(:context) { 'tags' }

    describe '#call' do
      subject { described_class.call(tag_names: tag_names, records: products, context: context) }

      it 'creates tags for each tag name' do
        expect { subject }.to change { ActsAsTaggableOn::Tag.count }.by(tag_names.size)
      end

      it 'creates taggings for each product-tag pair' do
        expect { subject }.to change { ActsAsTaggableOn::Tagging.count }.by(products.size * tag_names.size)
      end

      it 'assigns correct attributes to taggings' do
        subject
        taggings = ActsAsTaggableOn::Tagging.last(products.size * tag_names.size)

        taggings.each do |tagging|
          expect(tagging.taggable_type).to eq('Spree::Product')
          expect(products.pluck(:id)).to include(tagging.taggable_id)
          expect(tag_names).to include(tagging.tag.name)
          expect(tagging.context).to eq(context)
        end
      end

      it 'touches all products' do
        expect { subject }.to change { Spree::Product.where(id: products.pluck(:id)).pluck(:updated_at) }
      end

      it 'publishes tagging.bulk_created event' do
        expect(Spree::Events).to receive(:publish).with('tagging.bulk_created', hash_including(:tagging_ids))
        subject
      end

      context 'when tag names are duplicated or have extra spaces' do
        let(:tag_names) { ['tag1', ' tag2 ', 'tag1', 'tag3'] }

        it 'creates unique tags without extra spaces' do
          expect { subject }.to change { ActsAsTaggableOn::Tag.count }.by(3)
          expect(ActsAsTaggableOn::Tag.pluck(:name)).to match_array(['tag1', 'tag2', 'tag3'])
        end
      end

      context 'when no records are provided' do
        let(:products) { [] }

        it 'does not create any taggings' do
          expect { subject }.not_to change { ActsAsTaggableOn::Tagging.count }
        end
      end

      context 'when no tag names are provided' do
        let(:tag_names) { [] }

        it 'does not create any tags or taggings' do
          expect { subject }.not_to change { ActsAsTaggableOn::Tag.count }
          expect { subject }.not_to change { ActsAsTaggableOn::Tagging.count }
        end
      end
    end
  end
end
