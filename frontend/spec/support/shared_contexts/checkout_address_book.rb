shared_context 'checkout address book' do
  before do
    @store = Spree::Store.current || create(:store)
    @state = Spree::State.all.first || create(:state)
    @zone = Spree::Zone.global || create(:global_zone)
    @zone.countries << Spree::Country.all
    @tax_category = Spree::TaxCategory.first || create(:tax_category)
    @shipping = Spree::ShippingMethod.find_by_name('UPS Ground') || create(:shipping_method, tax_category: @tax_category)

    create(:check_payment_method)
    reset_spree_preferences do |config|
      config.company = true
      config.alternative_shipping_phone = false
    end

    create(:product_in_stock, name: 'Ruby on Rails Mug', price: 13.99)

    add_to_cart('Ruby on Rails Mug')
  end

  let(:state) { @state }

  private

  def should_have_address_fields
    expect(page).to have_field('First Name')
    expect(page).to have_field('Last Name')
    expect(page).to have_field(I18n.t('activerecord.attributes.spree/address.address1'))
    expect(page).to have_field('City')
    expect(page).to have_field('Country')
    expect(page).to have_field(I18n.t('activerecord.attributes.spree/address.zipcode'))
    expect(page).to have_field(I18n.t('activerecord.attributes.spree/address.phone'))
  end

  def complete_checkout
    click_button Spree.t(:save_and_continue)
    choose 'UPS Ground'
    click_button Spree.t(:save_and_continue)
    choose 'Check'
    click_button Spree.t(:save_and_continue)
  end

  def fill_in_address(address, type = :bill)
    fill_in 'First Name', with: address.firstname
    fill_in 'Last Name', with: address.lastname
    fill_in 'Company', with: address.company if Spree::Config[:company]
    fill_in I18n.t('activerecord.attributes.spree/address.address1'), with: address.address1
    fill_in I18n.t('activerecord.attributes.spree/address.address2'), with: address.address2
    select address.state.name, from: "order_#{type}_address_attributes_state_id"
    fill_in 'City', with: address.city
    fill_in I18n.t('activerecord.attributes.spree/address.zipcode'), with: address.zipcode
    fill_in I18n.t('activerecord.attributes.spree/address.phone'), with: address.phone
  end

  def expected_address_format(address)
    [
      "#{address.firstname} #{address.lastname}",
      address.company.to_s,
      address.address1.to_s,
      address.address2.to_s,
      "#{address.city} #{address.state ? address.state.abbr : address.state_name} #{address.zipcode}",
      address.country.to_s
    ].reject(&:empty?).join("\n")
  end
end
