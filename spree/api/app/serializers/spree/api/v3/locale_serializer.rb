module Spree
  module Api
    module V3
      # Serializes a Spree::Locale. The display name, default flag, and RTL
      # direction all live on the model — this is a thin projection of it.
      class LocaleSerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize code: :string, name: :string, default: :boolean, rtl: :boolean

        attributes :code, :name

        attribute(:default, &:default?)
        attribute(:rtl, &:rtl?)
      end
    end
  end
end
