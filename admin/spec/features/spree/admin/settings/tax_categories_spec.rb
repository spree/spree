require 'spec_helper'

RSpec.feature 'Tax categories' do
  stub_authorization!

  it 'allows to create new tax category' do
    visit spree.admin_tax_categories_path
    click_on 'New Tax Category'

    fill_in 'Name', with: 'New Tax Category'
    fill_in 'Description', with: 'New Tax Category Description'
    fill_in 'Tax Code', with: 'NEW_TAX_CATEGORY'
    check 'Is default', allow_label_click: true

    click_on 'Create'

    wait_for_turbo
    expect(page).to have_content 'Tax Category "New Tax Category" has been successfully created!'

    expect(Spree::TaxCategory.count).to eq 1

    tax_category = Spree::TaxCategory.first

    expect(tax_category.name).to eq 'New Tax Category'
    expect(tax_category.description).to eq 'New Tax Category Description'
    expect(tax_category.tax_code).to eq 'NEW_TAX_CATEGORY'
    expect(tax_category.is_default).to eq true
  end

  it 'allows to edit tax category' do
    tax_category = create(
      :tax_category,
      name: 'Standard',
      description: 'Standard Tax Category',
      tax_code: 'STANDARD_TAX_CATEGORY',
      is_default: true
    )

    visit spree.admin_tax_categories_path
    click_on 'Edit'

    fill_in 'Name', with: 'Non-Taxable'
    fill_in 'Description', with: 'Non-Taxable Tax Category'
    fill_in 'Tax Code', with: 'NON_TAXABLE_TAX_CATEGORY'
    uncheck 'Is default', allow_label_click: true

    within('#page-header') { click_button 'Update' }

    wait_for_turbo
    expect(page).to have_content 'Tax Category "Non-Taxable" has been successfully updated!'

    tax_category.reload

    expect(tax_category.name).to eq 'Non-Taxable'
    expect(tax_category.description).to eq 'Non-Taxable Tax Category'
    expect(tax_category.tax_code).to eq 'NON_TAXABLE_TAX_CATEGORY'
    expect(tax_category.is_default).to eq false
  end

  it 'allows to delete tax category', js: true do
    create(:tax_category)

    visit spree.admin_tax_categories_path
    click_on 'Edit'
    wait_for_turbo

    accept_confirm do
      click_on 'Delete'
    end

    wait_for_turbo

    expect(Spree::TaxCategory.count).to eq 0
  end
end
