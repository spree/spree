module Spree
  module Admin
    module BaseHelper
      include Spree::ImagesHelper

      def render_admin_partials(section, options = {})
        Rails.application.config.spree_admin.send(section).map do |partial|
          render partial, options
        end.join.html_safe
      end

      def enterprise_edition?
        defined?(SpreeEnterprise)
      end

      def spree_updater
        @spree_updater ||= Spree::Admin::Updater
      end

      def spree_update_available?
        @spree_update_available ||= !Rails.env.test? && spree_updater.update_available?
      end

      # check if the current controller is a settings controller
      # this is used to display different sidebar navigation for settings pages
      # @return [Boolean]
      def settings_active?
        @settings_active || %w[admin_users audits custom_domains exports imports invitations oauth_applications
                               payment_methods refund_reasons reimbursement_types return_authorization_reasons roles
                               shipping_categories shipping_methods stock_locations store_credit_categories
                               stores tax_categories tax_rates webhooks webhooks_subscribers zones].include?(controller_name)
      end

      # @return [Array<String>] the available countries for checkout
      def available_countries_iso
        @available_countries_iso ||= current_store.countries_available_for_checkout.pluck(:iso)
      end

      # render an avatar for a user
      # if user doesn't have an avatar, the user's initials will be displayed on a rounded background
      # @param user [Spree::User] the user to render the avatar for
      # @param options [Hash] the options for the avatar
      # @option options [Integer] :width the width of the avatar, default: 128
      # @option options [Integer] :height the height of the avatar, default: 128
      # @option options [String] :class the CSS class(es) of the avatar, default: 'avatar'
      # @return [String] the avatar
      def render_avatar(user, options = {})
        return unless user.present?

        options[:width] ||= 128
        options[:height] ||= 128
        options[:class] ||= 'avatar'

        if user.respond_to?(:avatar) && user.avatar.attached? && user.avatar.variable?
          spree_image_tag(
            user.avatar,
            width: options[:width],
            height: options[:height],
            class: options[:class],
            style: "width: #{options[:width]}px; height: #{options[:height]}px;"
          )
        else
          content_tag(:div, user.name&.initials, class: options[:class], style: "width: #{options[:width]}px; height: #{options[:height]}px;")
        end
      end

      # returns the available display on options, eg backend, frontend, both
      # @return [Array<Array<String, String>>] the available display on options
      def display_on_options
        Spree::DisplayOn::DISPLAY.map do |display_on|
          [Spree.t("admin.display_on_options.#{display_on}"), display_on]
        end
      end

      # render an error message for a form field
      # @param object [Spree::Model] the object to render the error message for
      # @param method [String] the method to render the error message for
      # @param options [Hash] the options for the error message
      # @return [String] the error message
      def error_message_on(object, method, _options = {})
        object = convert_to_model(object)
        obj = object.respond_to?(:errors) ? object : instance_variable_get("@#{object}")

        if obj && obj.errors[method].present?
          errors = safe_join(obj.errors[method], '<br />'.html_safe)
          content_tag(:span, errors, class: 'formError')
        else
          ''
        end
      end

      # render an icon, using the tabler icons library
      # @param icon_name [String] the name of the icon, eg: 'pencil', see: https://tabler.io/icons
      # @param options [Hash] the options for the icon
      # @return [String] the icon
      def icon(icon_name, options = {})
        if icon_name.ends_with?('.svg')
          icon_name = File.basename(icon_name, File.extname(icon_name))
        end

        # translations for legacy icon names
        icon_name = 'device-floppy' if icon_name == 'save'
        icon_name = 'pencil' if icon_name == 'edit'
        icon_name = 'trash' if icon_name == 'delete'
        icon_name = 'plus' if icon_name == 'add'
        icon_name = 'x' if icon_name == 'cancel'

        styles = options[:style]
        styles ||= ''
        styles += ";font-size: #{options[:height]}px !important;line-height:#{options[:height]}px !important" if options[:height]

        content_tag :i, nil, class: "ti ti-#{icon_name} #{options[:class]}", style: styles
      end

      # returns the flag emoji for a country
      # @param iso [String] the ISO code of the country
      # @return [String] the flag emoji
      def flag_emoji(iso)
        ::Country.new(iso).emoji_flag
      end

      # render a form field for a preference, according to the type of the preference (number, decimal, boolean, string, password, text)
      # see https://spreecommerce.org/docs/developer/customization/model-preferences
      # @param form [ActionView::Helpers::FormBuilder] the form builder
      # @param field [String] the name of the field
      # @param options [Hash] the options for the field
      # @return [String] the preference field
      def preference_field_for(form, field, options)
        case options[:type]
        when :integer
          form.number_field(field, preference_field_options(options))
        when :decimal
          form.number_field(field, preference_field_options(options))
        when :boolean
          form.check_box(field, preference_field_options(options))
        when :string
          form.text_field(field, preference_field_options(options))
        when :password
          render 'spree/admin/preferences/password_field', form: form, field: field, options: options
        when :text
          form.text_area(field, preference_field_options(options))
        else
          form.text_field(field, preference_field_options(options))
        end
      end

      # returns the options for a preference field, according to the type of the preference (number, decimal, boolean, string, password, text)
      # @param options [Hash] the options for the field
      # @option options [Symbol] :type the type of the preference, eg. :integer, :decimal, :boolean, :string, :password, :text
      # @option options [Boolean] :disabled whether the field is disabled
      # @return [Hash] the options for the field
      def preference_field_options(options)
        field_options = case options[:type]
                        when :integer
                          {
                            size: 10,
                            class: 'input_integer form-control'
                          }
                        when :decimal
                          {
                            size: 10,
                            class: 'input_decimal form-control',
                            step: options[:step] || 0.01
                          }
                        when :boolean
                          {
                            class: 'custom-control-input'
                          }
                        when :string
                          {
                            size: 10,
                            class: 'input_string form-control'
                          }
                        when :password
                          {
                            size: 10,
                            class: 'password_string form-control'
                          }
                        when :text
                          {
                            rows: 15,
                            cols: 85,
                            class: 'form-control'
                          }
                        else
                          {
                            size: 10,
                            class: 'input_string form-control'
                          }
                        end

        field_options.merge!(readonly: options[:readonly],
                             disabled: options[:disabled],
                             size: options[:size])
      end

      # renders all the preference fields for an object
      # @param object [Spree::TaxRate, Spree::Calculator, Spree::PaymentMethod, Spree::ShippingMethod, Spree::Store] the object to render the preference fields for
      # @param form [ActionView::Helpers::FormBuilder] the form builder
      # @param i18n_scope [String] the i18n scope for the preference fields
      # @return [String] the preference fields
      def preference_fields(object, form, i18n_scope: '')
        return unless object.respond_to?(:preferences)

        fields = object.preferences.keys.map { |key| preference_field(object, form, key, i18n_scope: i18n_scope) }
        safe_join(fields)
      end

      def preference_field(object, form, key, i18n_scope: '')
        return unless object.has_preference?(key)

        case key
        when :currency
          content_tag(:div, form.label("preferred_#{key}", Spree.t(key, scope: i18n_scope)) +
            form.currency_select("preferred_#{key}", current_store.supported_currencies.split(','), {}, { class: 'custom-select', disabled: current_store.supported_currencies.split(',').count == 1 }),
                      class: 'form-group', id: [object.class.to_s.parameterize, 'preference', key].join('-'))
        else
          if object.preference_type(key).to_sym == :boolean
            content_tag(:div, class: 'form-group custom-control custom-checkbox') do
              preference_field_for(form, "preferred_#{key}", type: object.preference_type(key)) +
                form.label(
                  "preferred_#{key}",
                  Spree.t(key, scope: i18n_scope),
                  class: 'custom-control-label',
                  id: [object.class.to_s.parameterize, 'preference', key].join('-')
                )
            end
          else
            content_tag(:div, form.label("preferred_#{key}", Spree.t(key, scope: i18n_scope)) +
              preference_field_for(form, "preferred_#{key}", type: object.preference_type(key)),
                        class: 'form-group', id: [object.class.to_s.parameterize, 'preference', key].join('-'))
          end
        end
      end

      def spree_dom_id(record)
        dom_id(record, 'spree')
      end

      # renders a red dot with a * to indicate that a field is required
      # @return [String] the required span tag
      def required_span_tag
        content_tag(:span, ' *', class: 'required font-weight-bold text-danger')
      end

      # renders a clipboard button
      # @param options [Hash] the options for the button
      # @option options [String] :class the CSS class(es) of the button
      # @option options [Hash] :data the data attributes for the button
      # @option options [String] :title the title of the button
      # @return [String] the button
      def clipboard_button(options = {})
        options[:class] ||= 'btn btn-clipboard with-tip'
        options[:type] ||= 'button'
        options[:data] ||= {}
        options[:data][:action] = 'clipboard#copy'
        options[:data][:clipboard_target] = 'button'
        options[:data][:title] = Spree.t('admin.copy_to_clipboard')
        options[:aria_label] ||= Spree.t('admin.copy_to_clipboard') # screen-reader label

        content_tag(:button, options) do
          icon('copy', class: 'mr-0 font-size-sm')
        end
      end

      # renders a clipboard component
      # @param text [String] the text to copy
      # @param options [Hash] the options for the component
      # @option options [String] :class the CSS class(es) of the component
      # @option options [Hash] :data the data attributes for the component
      # @option options [String] :title the title of the component
      # @return [String] the component
      def clipboard_component(text, options = {})
        options[:data] ||= {}
        options[:data][:controller] = 'clipboard'
        options[:data][:clipboard_success_content_value] ||= raw(icon('check', class: 'mr-0 font-size-sm'))

        content_tag(:span, data: options[:data]) do
          hidden_field_tag(:clipboard_source, text, data: { clipboard_target: 'source' }) +
            clipboard_button
        end
      end

      # returns the allowed file types for upload, according to the active storage configuration
      # @return [Array<String>] the allowed file types for upload, eg. ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
      def allowed_file_types_for_upload
        Rails.application.config.active_storage.web_image_content_types
      end
    end
  end
end
