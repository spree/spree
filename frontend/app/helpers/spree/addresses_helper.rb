# https://github.com/spree-contrib/spree_address_book/blob/master/app/helpers/spree/addresses_helper.rb
module Spree
  module AddressesHelper
    def address_field(form, method, address_id = 'b', &handler)
      content_tag :div, id: [address_id, method].join, class: 'form-group' do
        if handler
          yield
        else
          is_required = Spree::Address.required_fields.include?(method)
          separator = is_required ? '<span class="required">*</span><br />' : '<br />'
          form.label(method) + separator.html_safe +
            form.text_field(method, class: [is_required ? 'required' : nil, 'form-control'].compact, required: is_required)
        end
      end
    end

    def address_state(form, country, _address_id = 'b')
      country ||= Spree::Country.find(Spree::Config[:default_country_id])
      have_states = country.states.any?
      state_elements = [
        form.collection_select(:state_id, country.states.order(:name),
                              :id, :name,
                              { include_blank: true },
                               class: have_states ? 'form-control' : 'hidden',
                               disabled: !have_states) +
          form.text_field(:state_name,
                          class: !have_states ? 'form-control' : 'hidden',
                          disabled: have_states)
      ].join.tr('"', "'").delete("\n")

      form.label(:state, Spree.t(:state)) + '<span class="req">*</span><br />'.html_safe +
        content_tag(:noscript, form.text_field(:state_name, class: 'required form-control')) +
        javascript_tag("document.write(\"#{state_elements.html_safe}\");")
    end
  end
end
