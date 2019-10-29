class Spree::Variant::OptionsPresentation
  WORDS_CONNECTOR = ', '.freeze

  attr_reader :variant

  def initialize(variant)
    @variant = variant
  end

  def to_sentence
    options = option_values
    options = sort_options(options)
    options = present_options(options)

    join_options(options)
  end

  private

  def option_values
    variant.option_values.includes(:option_type).to_a
  end

  def sort_options(options)
    options.sort_by { |o| o.option_type.position }
  end

  def present_options(options)
    options.map do |ov|
      method = "present_#{ov.option_type.name}_option"

      respond_to?(method, true) ? send(method, ov) : present_option(ov)
    end
  end

  def present_color_option(ov)
    "#{ov.option_type.presentation}: #{ov.name}"
  end

  def present_option(ov)
    "#{ov.option_type.presentation}: #{ov.presentation}"
  end

  def join_options(options)
    options.to_sentence(words_connector: WORDS_CONNECTOR, two_words_connector: WORDS_CONNECTOR)
  end
end
