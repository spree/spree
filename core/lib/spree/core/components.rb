module Spree
  module Core
    class Engine < ::Rails::Engine
      def self.api_available?
        @@api_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('Spree::Api::Engine')
      end

      # old, legacy admin
      def self.backend_available?
        @@backend_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('Spree::Backend::Engine')
      end

      # new shiny admin
      def self.admin_available?
        @@admin_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('Spree::Admin::Engine')
      end

      def self.frontend_available?
        @@frontend_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('Spree::Storefront::Engine')
      end

      def self.emails_available?
        @@emails_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('Spree::Emails::Engine')
      end

      def self.sample_available?
        @@sample_available ||= ::Rails::Engine.subclasses.map(&:instance).map { |e| e.class.to_s }.include?('SpreeSample::Engine')
      end
    end
  end
end
