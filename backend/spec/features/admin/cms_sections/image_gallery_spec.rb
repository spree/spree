require 'spec_helper'

describe 'Image Gallery section', type: :feature do
  stub_authorization!

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:section) { create(:cms_image_gallery_section, cms_page: feature_page, name: 'Test Section') }
  let!(:taxonomy) { create(:taxon, name: 'Shirts', permalink: 'all-ts') }
  let!(:product) { create(:product, name: 'Zomg Shirt', slug: 'black-zomg-shirt') }
  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }


  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: 'Test Section')
      expect(page).to have_select('Section Type', selected: 'Image Gallery')
      expect(page).to have_content('Options For: Image Gallery')

      within 'div#image_a_details' do
        expect(page).to have_content('Image A')
        expect(page).to have_content('Title')

        if Rails::VERSION::STRING >= '6.0'
          expect(page).to have_select('Link To', selected: 'Taxon')
        end
      end

      within 'div#image_b_details' do
        expect(page).to have_content('Image B')
        expect(page).to have_content('Title')

        if Rails::VERSION::STRING >= '6.0'
          expect(page).to have_select('Link To', selected: 'Taxon')
        end
      end

      within 'div#image_c_details' do
        expect(page).to have_content('Image C')
        expect(page).to have_content('Title')

        if Rails::VERSION::STRING >= '6.0'
          expect(page).to have_select('Link To', selected: 'Taxon')
        end
      end

      expect(page).to have_select('Layout Style', selected: 'Default')
      expect(page).to have_select('Fit To', selected: 'Container')
      expect(page).to have_select('Display labels', selected: 'Show')
    end

    it 'allows the selection of layout style and saves to database' do
      select2('Reversed', from: 'Layout Style')
      click_on 'Update'
      expect(page).to have_select('Layout Style', selected: 'Reversed')
    end

    it 'allows the selection of Fit To and saves to database' do
      select2('Screen', from: 'Fit To')
      click_on 'Update'
      expect(page).to have_select('Fit To', selected: 'Screen')
    end

    it 'allows the selection of Display Labels and saves to database' do
      select2('Hide', from: 'Display labels')
      click_on 'Update'
      expect(page).to have_select('Display labels', selected: 'Hide')
    end

    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end

    context 'Editing Image A' do
      it 'allows admin to enter and save details' do
        within 'div#image_a_details' do
          fill_in 'Title', with: 'Trendy Styles'
        end

        select2('Shirts', css: '#cms_section_link_one_field', search: true)

        click_on 'Update'

        within 'div#image_a_details' do
          expect(page).to have_field('Title', with: 'Trendy Styles')

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

          within 'div#image_a_details' do
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

    context 'Editing Image B' do
      it 'allows admin to enter and save details' do
        within 'div#image_b_details' do
          fill_in 'Title', with: 'Trendy Styles'
        end

        select2('Shirts', css: '#cms_section_link_two_field', search: true)

        click_on 'Update'

        within 'div#image_b_details' do
          expect(page).to have_field('Title', with: 'Trendy Styles')

          wait_for_ajax do
            expect(page).to have_select('Link To Taxon', selected: 'Shirts', value: 'all-ts', visible: :all)
          end
        end
      end

      if Rails::VERSION::STRING >= '6.0'
        it 'allows admin to change the link type and save a product' do
          select2('Product', css: '#cms_section_link_type_two_field')

          click_on 'Update'

          select2('Zomg Shirt', css: '#cms_section_link_two_field', search: true)

          click_on 'Update'

          within 'div#image_b_details' do
            wait_for_ajax do
              expect(page).to have_select('Link To Product', selected: 'Zomg Shirt', value: 'black-zomg-shirt', visible: :all)
            end
          end
        end
      end

      it 'admin should be able to add image' do
        attach_file('cms_section_image_two', file_path)

        click_button 'Update'

        expect(page).to have_content('successfully updated!')
        expect(page).to have_css('.admin-img-holder img')
      end
    end

    context 'Editing Image C' do
      it 'allows admin to enter and save details' do
        within 'div#image_c_details' do
          fill_in 'Title', with: 'Trendy Styles'
        end

        select2('Shirts', css: '#cms_section_link_three_field', search: true)

        click_on 'Update'

        within 'div#image_c_details' do
          expect(page).to have_field('Title', with: 'Trendy Styles')

          wait_for_ajax do
            expect(page).to have_select('Link To Taxon', selected: 'Shirts', value: 'all-ts', visible: :all)
          end
        end
      end

      if Rails::VERSION::STRING >= '6.0'
        it 'allows admin to change the link type and save a product' do
          select2('Product', css: '#cms_section_link_type_three_field')

          click_on 'Update'

          select2('Zomg Shirt', css: '#cms_section_link_three_field', search: true)

          click_on 'Update'

          within 'div#image_c_details' do
            wait_for_ajax do
              expect(page).to have_select('Link To Product', selected: 'Zomg Shirt', value: 'black-zomg-shirt', visible: :all)
            end
          end
        end
      end

      it 'admin should be able to add image' do
        attach_file('cms_section_image_three', file_path)

        click_button 'Update'

        expect(page).to have_content('successfully updated!')
        expect(page).to have_css('.admin-img-holder img')
      end
    end
  end
end
