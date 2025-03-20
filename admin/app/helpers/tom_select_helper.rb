# frozen_string_literal: true

module TomSelectHelper
  #
  # @param [String] name
  # @param [Hash] options
  def tom_select_tag(name, options = { template: false, multiple: false, url: nil, active_option: nil, class: 'w-100', create: false, select_data: {} })
    stimulus_options = options[:data] || {}
    stimulus_options[:controller] = 'select' unless options[:template].present?
    stimulus_options['select-active-option-value'] = options[:active_option].as_json if options[:active_option]
    stimulus_options['select-empty-option-value'] = options[:empty_option] if options[:empty_option]
    stimulus_options['select-options-value'] = options[:options].as_json if options[:options]
    stimulus_options['select-url-value'] = options[:url] if options[:url]
    stimulus_options['select-remote-search-value'] = options[:remote_search] if options[:remote_search]
    stimulus_options['select-remote-search-params-value'] = options[:remote_search_params] if options[:remote_search_params]
    stimulus_options['select-remote-search-active-option-value'] = options[:remote_search_active_option].as_json if options[:remote_search_active_option]
    stimulus_options['select-multiple-value'] = options[:multiple]
    stimulus_options['select-create-value'] = options[:create]
    stimulus_options['select-value-field-value'] = options[:value_field] if options[:value_field].present?
    stimulus_options['select-search-field-value'] = options[:value_field] if options[:search_field].present?
    stimulus_options['select-label-field-value'] = options[:value_field] if options[:label_field].present?
    stimulus_options['select-sort-field-value'] = options[:value_field] if options[:sort_field].present?
    html_select_options = if options[:grouped_options].present?
                            grouped_options_for_select(options[:grouped_options], options[:active_option])
                          else
                            options_for_select(
                              options[:options] || options[:preloaded_options] || [], options[:active_option]
                            )
                          end

    content_tag :div, data: stimulus_options, class: options[:class] do
      select_tag name, html_select_options,
                 multiple: options[:multiple],
                 data: { 'select-target': 'input', **(options[:select_data] || {}) },
                 class: options[:select_class] || 'd-none',
                 required: options[:required],
                 disabled: options[:disabled],
                 include_blank: options[:include_blank],
                 placeholder: options[:placeholder]
    end
  end
end
