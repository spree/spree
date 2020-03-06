# https://github.com/spree-contrib/spree_address_book/blob/master/app/helpers/spree/addresses_helper.rb
module Spree
  module AddressesHelper
    def address_field(form, method, address_id = 'b', &handler)
      content_tag :p, id: [address_id, method].join, class: 'form-group checkout-content-inner-field' do
        if handler
          yield
        else
          is_required = Spree::Address.required_fields.include?(method)
          method_name = I18n.t("activerecord.attributes.spree/address.#{method}")
          required = Spree.t(:required)
          form.text_field(method,
                          class: [is_required ? 'required' : nil, 'spree-flat-input'].compact,
                          required: is_required,
                          placeholder: is_required ? "#{method_name} #{required}" : method_name)
        end
      end
    end

    def address_state(form, country, _address_id = 'b')
      country ||= Spree::Country.find(Spree::Config[:default_country_id])
      have_states = country.states.any?
      state_elements = [
        form.collection_select(:state_id, country.states.order(:name),
                              :id, :name,
                               { prompt: Spree.t(:state).upcase },
                               class: have_states ? 'required form-control spree-flat-select' : 'hidden',
                               disabled: !have_states) +
          form.text_field(:state_name, class: !have_states ? 'required' : 'hidden', disabled: have_states) +
          image_tag('arrow.svg', class: 'position-absolute spree-flat-select-arrow')
      ].join.tr('"', "'").delete("\n")

      content_tag(:noscript, form.text_field(:state_name, class: 'required')) +
        javascript_tag("document.write(\"<span class='d-block position-relative'>#{state_elements.html_safe}</span>\");")
    end

    def user_available_addresses
      return unless try_spree_current_user

      try_spree_current_user.addresses.where(country: available_countries)
    end
  end
end
