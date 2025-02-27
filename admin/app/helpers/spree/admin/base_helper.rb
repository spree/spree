module Spree
  module Admin
    module BaseHelper
      include Spree::ImagesHelper

      def enterprise_edition?
        defined?(Vendo)
      end

      def spree_update_available?
        @spree_update_available ||= !Rails.env.test? && Spree::Admin::Updater.update_available?
      end

      def available_countries_iso
        @available_countries_iso ||= current_store.countries_available_for_checkout.pluck(:iso)
      end

      def avatar_url_for(user)
        return unless user.present?

        if user.respond_to?(:avatar) && user.avatar.attached? && user.avatar.variable?
          main_app.cdn_image_url(
            user.avatar.variant(spree_image_variant_options(resize_to_fill: [128, 128]))
          )
        else
          "https://eu.ui-avatars.com/api/?name=#{user.name&.initials}&background=random"
        end
      end

      def display_on_options
        Spree::DisplayOn::DISPLAY.map do |display_on|
          [Spree.t("admin.display_on_options.#{display_on}"), display_on]
        end
      end

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

      def flag_emoji(iso)
        ::Country.new(iso).emoji_flag
      end

      def preference_field_tag(name, value, options)
        if options[:key] == :currency
          return select_tag(
            name,
            currency_options_for_select(
              value,
              current_store.supported_currencies.split(',')
            ),
            class: 'custom-select',
            disabled: current_store.supported_currencies.split(',').count == 1
          )
        end

        case options[:type]
        when :integer
          number_field_tag(name, value, preference_field_options(options))
        when :decimal
          number_field_tag(name, value, preference_field_options(options))
        when :boolean
          hidden_field_tag(name, 0, id: "#{name}_hidden") +
            check_box_tag(name, 1, value, preference_field_options(options))
        when :string
          text_field_tag(name, value, preference_field_options(options))
        when :password
          password_field_tag(name, value, preference_field_options(options))
        when :text
          text_area_tag(name, value, preference_field_options(options))
        else
          text_field_tag(name, value, preference_field_options(options))
        end
      end

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

      def preference_fields(object, form)
        return unless object.respond_to?(:preferences)

        fields = object.preferences.keys.map do |key|
          if object.has_preference?(key)
            case key
            when :currency
              content_tag(:div, form.label("preferred_#{key}", Spree.t(key)) +
                form.currency_select("preferred_#{key}", current_store.supported_currencies.split(','), {}, { class: 'custom-select', disabled: current_store.supported_currencies.split(',').count == 1 }),
                          class: 'form-group', id: [object.class.to_s.parameterize, 'preference', key].join('-'))
            else
              if object.preference_type(key).to_sym == :boolean
                content_tag(:div, class: 'custom-control custom-checkbox') do
                  preference_field_for(form, "preferred_#{key}", type: object.preference_type(key)) +
                    form.label(
                      "preferred_#{key}",
                      Spree.t(key),
                      class: 'custom-control-label',
                      id: [object.class.to_s.parameterize, 'preference', key].join('-')
                    )
                end
              else
                content_tag(:div, form.label("preferred_#{key}", Spree.t(key)) +
                  preference_field_for(form, "preferred_#{key}", type: object.preference_type(key)),
                            class: 'form-group', id: [object.class.to_s.parameterize, 'preference', key].join('-'))
              end
            end
          end
        end
        safe_join(fields)
      end

      def spree_dom_id(record)
        dom_id(record, 'spree')
      end

      def required_span_tag
        content_tag(:span, ' *', class: 'required font-weight-bold text-danger')
      end

      def external_page_preview_link(resource, options = {})
        resource_name = options[:name] || resource.class.name.demodulize

        url = if [Spree::Product, Spree::Post].include?(resource.class)
                spree_storefront_resource_url(resource, preview_id: resource.id)
              else
                spree_storefront_resource_url(resource)
              end

        link_to_with_icon(
          'eye',
          Spree.t('admin.utilities.preview', name: resource_name),
          url,
          class: 'text-left dropdown-item', id: "adminPreview#{resource_name}", target: :blank, data: { turbo: false }
        )
      end

      def path_from_url(url)
        url.to_s.gsub('https://', '').gsub('http://', '')
      end
    end
  end
end
