require 'spec_helper'

describe 'Prototypes', type: :feature, js: true do
  stub_authorization!

  context 'listing prototypes' do
    it 'is able to list existing prototypes' do
      create(:property, name: 'model', presentation: 'Model')
      create(:property, name: 'brand', presentation: 'Brand')
      create(:property, name: 'shirt_fabric', presentation: 'Fabric')
      create(:property, name: 'shirt_sleeve_length', presentation: 'Sleeve')
      create(:property, name: 'mug_type', presentation: 'Type')
      create(:property, name: 'bag_type', presentation: 'Type')
      create(:property, name: 'manufacturer', presentation: 'Manufacturer')
      create(:property, name: 'bag_size', presentation: 'Size')
      create(:property, name: 'mug_size', presentation: 'Size')
      create(:property, name: 'gender', presentation: 'Gender')
      create(:property, name: 'shirt_fit', presentation: 'Fit')
      create(:property, name: 'bag_material', presentation: 'Material')
      create(:property, name: 'shirt_type', presentation: 'Type')
      p = create(:prototype, name: 'Shirt')
      %w(brand gender manufacturer model shirt_fabric shirt_fit shirt_sleeve_length shirt_type).each do |prop|
        p.properties << Spree::Property.find_by(name: prop)
      end
      p = create(:prototype, name: 'Mug')
      %w(mug_size mug_type).each do |prop|
        p.properties << Spree::Property.find_by(name: prop)
      end
      p = create(:prototype, name: 'Bag')
      %w(bag_type bag_material).each do |prop|
        p.properties << Spree::Property.find_by(name: prop)
      end

      visit spree.admin_path
      click_link 'Products'
      click_link 'Prototypes'

      within_row(1) { expect(column_text(1)).to eq 'Shirt' }
      within_row(2) { expect(column_text(1)).to eq 'Mug' }
      within_row(3) { expect(column_text(1)).to eq 'Bag' }
    end
  end

  context 'creating a prototype' do
    it 'allows an admin to create a new product prototype' do
      visit spree.admin_path
      click_link 'Products'
      click_link 'Prototypes'

      click_link 'new_prototype_link'
      within('.content-header') do
        expect(page).to have_content('New Prototype')
      end
      fill_in 'prototype_name', with: 'male shirts'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      visit spree.admin_prototypes_path
      within_row(1) { click_icon :edit }
      fill_in 'prototype_name', with: 'Shirt 99'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_content('Shirt 99')
    end
  end

  context 'editing a prototype' do
    it 'allows to empty its properties' do
      model_property = create(:property, name: 'model', presentation: 'Model')
      brand_property = create(:property, name: 'brand', presentation: 'Brand')

      shirt_prototype = create(:prototype, name: 'Shirt', properties: [])
      %w(brand model).each do |prop|
        shirt_prototype.properties << Spree::Property.find_by(name: prop)
      end

      visit spree.admin_path
      click_link 'Products'
      click_link 'Prototypes'

      click_icon :edit
      property_ids = find_field('prototype_property_ids').value.map(&:to_i)
      expect(property_ids).to match_array [model_property.id, brand_property.id]

      unselect 'Brand', from: 'prototype_property_ids'
      unselect 'Model', from: 'prototype_property_ids'

      click_button 'Update'

      click_icon :edit

      expect(find_field('prototype_property_ids').value).to be_empty
    end
  end

  it 'is deletable' do
    shirt_prototype = create(:prototype, name: 'Shirt', properties: [])
    shirt_prototype.taxons << create(:taxon)

    visit spree.admin_path
    click_link 'Products'
    click_link 'Prototypes'

    spree_accept_alert do
      within("#spree_prototype_#{shirt_prototype.id}") do
        page.find('.delete-resource').click
      end
      wait_for_ajax

      expect(page).to have_content("Prototype \"#{shirt_prototype.name}\" has been successfully removed!")
    end
  end
end
