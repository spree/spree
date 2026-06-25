module Spree
  module Api
    module V3
      class LocaleSerializer
        include Alba::Resource
        include Typelizer::DSL

        # ISO 639-1 language codes that use right-to-left scripts.
        RTL_LANGUAGE_CODES = %w[ar he fa ur yi].freeze

        typelize code: :string, name: :string, default: :boolean, rtl: :boolean

        attributes :code, :name

        # True for the store's primary (source) locale, which the admin
        # translation form edits at the top level.
        attribute :default do |locale|
          params[:default_locale].present? && locale.code.to_s == params[:default_locale].to_s
        end

        # True for right-to-left scripts (Arabic, Hebrew, …) so clients can set
        # the layout direction.
        attribute :rtl do |locale|
          language_code = locale.code.to_s.tr('_', '-').split('-', 2).first
          RTL_LANGUAGE_CODES.include?(language_code)
        end
      end
    end
  end
end
