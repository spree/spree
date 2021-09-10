require 'spec_helper'

describe 'Image Side By Side Images section', type: :feature do
  stub_authorization!

  section_type = 'Side By Side Images'

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:section) { create(:cms_side_by_side_images_section, cms_page: feature_page, name: "Test #{section_type}") }
  let!(:taxonomy) { create(:taxon, name: 'Shirts', permalink: 'all-ts') }
  let!(:product) { create(:product, name: 'Zomg Shirt', slug: 'black-zomg-shirt') }
  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }

  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: "Test #{section_type}")
      expect(page).to have_select('Section Type', selected: section_type)
      expect(page).to have_content("Options For: #{section_type}")

      within 'div#left_image_details' do
        expect(page).to have_content('Left Image')
        expect(page).to have_field('Title')
        expect(page).to have_field('Subtitle')

        if Rails::VERSION::STRING >= '6.0'
          expect(page).to have_select('Link To', selected: 'Taxon')
        end
      end

      within 'div#right_image_details' do
        expect(page).to have_content('Right Image')
        expect(page).to have_field('Title')
        expect(page).to have_field('Subtitle')

        if Rails::VERSION::STRING >= '6.0'
          expect(page).to have_select('Link To', selected: 'Taxon')
        end
      end

      expect(page).to have_select('Fit To', selected: 'Container')
      expect(page).to have_select('Set Gutters', selected: 'Gutters')
    end

    it 'allows the selection of Fit To and saves to database' do
      select2('Screen', from: 'Fit To')
      click_on 'Update'
      expect(page).to have_select('Fit To', selected: 'Screen')
    end

    it 'allows the selection of Gutters and saves to database' do
      select2('No Gutters', from: 'Set Gutters')
      click_on 'Update'
      expect(page).to have_select('Set Gutters', selected: 'No Gutters')
    end

    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end

    context 'Editing Left Image' do
      it 'allows admin to enter and save details' do
        within 'div#left_image_details' do
          fill_in 'Title', with: 'Trendy Styles'
          fill_in 'Subtitle', with: 'Shop Today'
        end

        select2('Shirts', css: '#cms_section_link_one_field', search: true)

        click_on 'Update'

        within 'div#left_image_details' do
          expect(page).to have_field('Title', with: 'Trendy Styles')
          expect(page).to have_field('Subtitle', with: 'Shop Today')

          wait_for_ajax do
            expect(page).to have_select('Link To Taxon', selected: 'Shirts', value: 'all-ts', visible: :all)
          end
        end
      end

      if Rails::VERSION::STRING >= '6.0'
        it 'allows admin to change the link type and save a product' do
          select2('Product', css: '#cms_section_link_type_one_field')

          click_on 'Update'

          select2('Zomg Shirt', css: '#cms_section_link_one_field', search: true)

          click_on 'Update'

          within 'div#left_image_details' do
            wait_for_ajax do
              expect(page).to have_select('Link To Product', selected: 'Zomg Shirt', value: 'black-zomg-shirt', visible: :all)
            end
          end
        end
      end

      it 'admin should be able to add image' do
        attach_file('cms_section_image_one', file_path)

        click_button 'Update'

        expect(page).to have_content('successfully updated!')
        expect(page).to have_css('.admin-img-holder img')
      end
    end

    context 'Editing Right Image' do
      it 'allows admin to enter and save details' do
        within 'div#right_image_details' do
          fill_in 'Title', with: 'Trendy Styles'
          fill_in 'Subtitle', with: 'Shop Today'
        end

        select2('Shirts', css: '#cms_section_link_one_field', search: true)

        click_on 'Update'

        within 'div#right_image_details' do
          expect(page).to have_field('Title', with: 'Trendy Styles')
          expect(page).to have_field('Subtitle', with: 'Shop Today')

          wait_for_ajax do
            expect(page).to have_select('Link To Taxon', selected: 'Shirts', value: 'all-ts', visible: :all)
          end
        end
      end

      if Rails::VERSION::STRING >= '6.0'
        it 'allows admin to change the link type and save a product' do
          select2('Product', css: '#cms_section_link_type_one_field')

          click_on 'Update'

          select2('Zomg Shirt', css: '#cms_section_link_one_field', search: true)

          click_on 'Update'

          within 'div#right_image_details' do
            wait_for_ajax do
              expect(page).to have_select('Link To Product', selected: 'Zomg Shirt', value: 'black-zomg-shirt', visible: :all)
            end
          end
        end
      end

      it 'admin should be able to add image' do
        attach_file('cms_section_image_one', file_path)

        click_button 'Update'

        expect(page).to have_content('successfully updated!')
        expect(page).to have_css('.admin-img-holder img')
      end
    end
  end
end
