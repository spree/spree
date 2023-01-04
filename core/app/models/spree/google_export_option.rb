module Spree
  class GoogleExportOption < Base
    belongs_to :store, class_name: "Spree::Store"

    validates :store, presence: true

    def export
      Spree::Dependencies.export_rss_google.constantize.new.call(self)
    end

    def enabled_keys
      keys = []

      attributes.each do |key, value|
        if value.instance_of?(TrueClass)
          keys.append(key.to_sym)
        end
      end

      keys
    end
  end
end
