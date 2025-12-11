# https://github.com/spree-contrib/spree_address_book/blob/master/app/helpers/spree/addresses_helper.rb
module Spree
  module AddressesHelper
    def address_field(form, method, address_id = 'b', required = false, text_field_attributes: {}, &handler)
      content_tag :div, id: [address_id, method].join, class: 'mb-4' do
        if handler
          yield
        else
          method_name = I18n.t("activerecord.attributes.spree/address.#{method}")
          form.label(method, method_name, class: 'block text-xs text-neutral-600 mb-1') +
          form.text_field(method,
                          class: ['text-input w-full'].compact,
                          placeholder: method_name,
                          required: required,
                          aria: { label: method_name },
                          **text_field_attributes)

        end
      end
    end

    def address_zipcode(form, country, address_id = 'b')
      method_name = Spree.t(:zipcode)
      form.label(:zipcode, method_name, id: address_id + '_zipcode_label', class: 'block text-xs text-neutral-600 mb-1') +
      form.text_field(:zipcode,
                      class: 'text-input',
                      placeholder: method_name,
                      required: country&.zipcode_required?,
                      data: { 'address-form-target': 'zipcode', address_autocomplete_target: 'zipcode' },
                      aria: { label: Spree.t(:zipcode) })
    end

    def address_state(form, country, address_id = 'b')
      country ||= address_default_country
      states_required = country.states_required?
      have_states = states_required && country.states.any?
      state_elements = [
        form.label(Spree.t(:state).downcase,
                   Spree.t(:state),
                   class: [have_states ? 'state-select-label' : nil, ' block text-xs text-neutral-600 mb-1'].compact,
                   id: address_id + '_state_label',
                   data: { 'address-form-target': 'stateLabel' }) +
          form.collection_select(:state_id, checkout_zone_applicable_states_for(country).sort_by(&:name),
                                 :id, :name,
                                 { prompt: Spree.t(:state) },
                                 class: 'select-input min-w-full max-w-full',
                                 data: { 'address-form-target': 'state', address_autocomplete_target: 'state' },
                                 required: have_states && states_required,
                                 aria: { label: Spree.t(:state) }) +
          form.text_field(:state_name,
                          class: 'ml-3 text-input',
                          aria: { label: Spree.t(:state) },
                          required: !have_states && states_required,
                          data: { 'address-form-target': 'stateName' },
                          placeholder: Spree.t(:state))
      ].join.tr('"', "'").delete("\n")

      content_tag :span, class: 'w-full state-select max-w-full' do
        state_elements.html_safe
      end
    end

    def available_states
      @available_states ||= Rails.cache.fetch(['available-states-v2', current_store.cache_key_with_version]) do
        Spree::State.where(country_id: available_countries).pluck(:country_id, :id, :abbr, :name)
      end
    end

    def current_store_countries_with_states_ids
      Spree::Deprecation.warn('current_store_countries_with_states_ids is deprecated and will be removed in Spree 5.3')

      @current_store_countries_with_states_ids ||= current_store.countries_available_for_checkout.find_all { |country| country.states_required? }.each_with_object([]) do |country, memo|
        memo << current_store.states_available_for_checkout(country)
      end.flatten.pluck(:country_id)
    end

    def current_store_countries_without_states_ids
      Spree::Deprecation.warn('current_store_countries_without_states_ids is deprecated and will be removed in Spree 5.3')

      @current_store_countries_without_states_ids ||= current_store.countries_available_for_checkout.find_all { |country| !country.states_required? }.pluck(:id)
    end

    def current_store_supported_countries_ids
      Spree::Deprecation.warn('current_store_supported_countries_ids is deprecated and will be removed in Spree 5.3')

      @current_store_supported_countries_ids ||= Rails.cache.fetch(['current_store_supported_countries_ids', current_store]) do
        (current_store_countries_with_states_ids + current_store_countries_without_states_ids).uniq
      end
    end

    def user_available_addresses
      return [] unless try_spree_current_user

      @user_available_addresses ||= begin
        try_spree_current_user.
          addresses.
          includes(:country, :state).
          not_quick_checkout.
          where(country_id: current_store.countries_available_for_checkout.pluck(:id)).
          includes(:user)
      end
    end

    def checkout_zone_applicable_states_for(country)
      current_store.states_available_for_checkout(country)
    end

    def address_default_country
      @address_default_country ||= current_store.default_country
    end
  end
end
