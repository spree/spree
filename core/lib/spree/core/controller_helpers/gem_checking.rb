module Spree
  module Core
    module ControllerHelpers
      module GemChecking
        extend ActiveSupport::Concern

        def backend_available?
          @backend_available ||= Gem::Specification.find_all_by_name('spree_backend').any?
        end

        def frontend_available?
          @frontend_available ||= Gem::Specification.find_all_by_name('spree_frontend').any?
        end

        def api_available?
          @api_available ||= Gem::Specification.find_all_by_name('spree_api').any?
        end

        def emails_available?
          @emails_available ||= Gem::Specification.find_all_by_name('spree_emails').any?
        end
      end
    end
  end
end

