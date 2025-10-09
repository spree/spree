module Spree
  module Admin
    module PostsControllerDecorator
      def self.prepended(base)
        base.include Spree::Admin::TranslationsHelper
        base.before_action :load_translations, only: [:edit, :update]
      end

      private

      def load_translations
        @translations = @post.translations.index_by(&:locale)
      end
    end
  end
end

Spree::Admin::PostsController.prepend Spree::Admin::PostsControllerDecorator
