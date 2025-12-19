require 'spec_helper'

RSpec.describe Spree::Taxon, type: :model do
  describe 'Callbacks' do
    describe 'after_destroy :remove_all_featured_sections' do
      let(:taxon) { create(:taxon) }
      let!(:featured_section) { create(:featured_taxon_page_section, preferred_taxon_id: taxon.id) }

      it 'removes the associated featured section' do
        expect { taxon.destroy! }.to change(Spree::PageSections::FeaturedTaxon, :count).from(3).to(2)
        expect(featured_section.reload).to be_deleted
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
