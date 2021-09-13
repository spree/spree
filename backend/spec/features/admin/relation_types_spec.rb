require 'spec_helper'

describe 'Admin Relation Types', type: :feature, js: true do
  stub_authorization!

  before do
    visit spree.admin_relation_types_path
  end

  scenario 'when no relation types exists' do
    expect(page).to have_text 'No Relation Types found, Add One!'
  end

  context 'create' do
    scenario 'can create a new relation type' do
      click_link 'New Relation Type'
      expect(current_path).to eq spree.new_admin_relation_type_path

      fill_in 'Name', with: 'Gears'
      fill_in 'Applies To', with: 'Spree:Products'

      click_button 'Create'

      expect(page).to have_text 'successfully created!'
      expect(current_path).to eq spree.admin_relation_types_path
    end

    scenario 'shows validation errors with blank :name' do
      click_link 'New Relation Type'
      expect(current_path).to eq spree.new_admin_relation_type_path

      fill_in 'Name', with: ''
      click_button 'Create'

      expect(page).to have_text 'Name can\'t be blank'
    end

    scenario 'shows validation errors with blank :applies_to' do
      click_link 'New Relation Type'
      expect(current_path).to eq spree.new_admin_relation_type_path

      fill_in 'Name', with: 'Gears'
      fill_in 'Applies To', with: ''
      click_button 'Create'

      expect(page).to have_text 'Applies to can\'t be blank'
    end
  end

  context 'with records' do
    before do
      %w(Gears Equipments).each do |name|
        create(:relation_type, name: name)
      end
      visit spree.admin_relation_types_path
    end

    context 'show' do
      scenario 'displays existing relation types' do
        within_row(1) do
          expect(column_text(1)).to eq 'Gears'
          expect(column_text(2)).to eq 'Spree::Product'
          expect(column_text(3)).to eq ''
        end
      end
    end

    context 'edit' do
      before do
        within_row(1) { click_icon :edit }
        expect(current_path).to eq spree.edit_admin_relation_type_path(1)
      end

      scenario 'can update an existing relation type' do
        fill_in 'Name', with: 'Gadgets'
        click_button 'Update'
        expect(page).to have_text 'successfully updated!'
        expect(page).to have_text 'Gadgets'
      end

      scenario 'shows validation errors with blank :name' do
        fill_in 'Name', with: ''
        click_button 'Update'
        expect(page).to have_text 'Name can\'t be blank'
      end
    end

    context 'delete' do
      scenario 'can remove records' do
        within_row(1) do
          expect(column_text(1)).to eq 'Gears'
          click_icon :delete
        end
        page.driver.browser.switch_to.alert.accept unless Capybara.javascript_driver == :poltergeist
        expect(page).to have_text 'successfully removed!'
      end
    end
  end
end
