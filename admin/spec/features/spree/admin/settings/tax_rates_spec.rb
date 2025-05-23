require 'spec_helper'

RSpec.feature 'Tax rates', js: true do
  stub_authorization!

  before do
    Spree::Seeds::Countries.call
    Spree::Seeds::Zones.call
    create(:tax_category, name: 'Default', is_default: true)
    create(:default_tax_calculator)
  end

  it 'allows Store Owner to create new tax rate' do
    visit spree.admin_tax_rates_path
    click_on 'New Tax Rate'

    fill_in 'Name', with: 'New Tax Rate'
    fill_in 'Rate', with: 0.10
    check 'Included in Price', allow_label_click: true
    check 'Show rate in label', allow_label_click: true
    select 'Default', from: 'Tax Category'
    select 'EU_VAT', from: 'Zone'
    select 'Default Tax', from: 'Calculator'

    click_on 'Create'

    wait_for_turbo
    expect(page).to have_content 'Tax Rate "New Tax Rate" has been successfully created!'

    expect(Spree::TaxRate.count).to eq 1

    tax_rate = Spree::TaxRate.first

    expect(tax_rate.name).to eq 'New Tax Rate'
    expect(tax_rate.amount).to eq 0.10
    expect(tax_rate.included_in_price).to eq true
    expect(tax_rate.show_rate_in_label).to eq true
    expect(tax_rate.tax_category.name).to eq 'Default'
    expect(tax_rate.zone.name).to eq 'EU_VAT'
    expect(tax_rate.calculator.class).to eq Spree::Calculator::DefaultTax
  end

  it 'allows Store Owner to edit tax rate' do
    tax_rate = create(
      :tax_rate,
      name: 'Standard',
      amount: 0.10,
      included_in_price: true,
      show_rate_in_label: true,
      tax_category: create(:tax_category, name: 'Standard'),
      zone: Spree::Zone.find_by(name: 'EU_VAT')
    )

    visit spree.admin_tax_rates_path
    click_on 'Edit'

    fill_in 'Name', with: 'Updated Tax Rate'
    fill_in 'Rate', with: 0.20
    uncheck 'Included in Price', allow_label_click: true
    uncheck 'Show rate in label', allow_label_click: true
    select 'Default', from: 'Tax Category'
    select 'Asia', from: 'Zone'
    select 'Default Tax', from: 'Calculator'

    within('#page-header') { click_button 'Update' }

    wait_for_turbo

    expect(page).to have_content 'Tax Rate "Updated Tax Rate" has been successfully updated!'

    expect(tax_rate.reload.name).to eq 'Updated Tax Rate'
    expect(tax_rate.amount).to eq 0.20
    expect(tax_rate.included_in_price).to eq false
    expect(tax_rate.show_rate_in_label).to eq false
    expect(tax_rate.tax_category.name).to eq 'Default'
    expect(tax_rate.zone.reload.name).to eq 'Asia'
    expect(tax_rate.calculator.class).to eq Spree::Calculator::DefaultTax
  end

  it 'allows Store Owner to delete tax rate' do
    tax_rate = create(:tax_rate)

    visit spree.admin_tax_rates_path
    click_on 'Edit'
    wait_for_turbo

    accept_confirm do
      click_on 'Delete'
    end

    wait_for_turbo

    expect(Spree::TaxRate.count).to eq 0
  end
end
