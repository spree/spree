module Spree
  class GoogleExportOption < Base
    def export
      Spree::Dependencies.export.constantize.new.export_google_rss(self)
    end

    def true_keys
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
