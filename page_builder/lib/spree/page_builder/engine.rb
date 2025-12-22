module Spree
  module PageBuilder
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_page_builder'

      # Add page builder fields to the core Environment struct
      initializer 'spree.page_builder.environment', before: :load_config_initializers do |app|
        # These will be initialized in after_initialize
      end

      config.after_initialize do
        Rails.application.config.spree.themes = [
          Spree::Themes::Default
        ]

        Rails.application.config.spree.theme_layout_sections = [
          Spree::PageSections::AnnouncementBar,
          Spree::PageSections::Header,
          Spree::PageSections::Newsletter,
          Spree::PageSections::Footer
        ]

        Rails.application.config.spree.pages = [
          Spree::Pages::Cart,
          Spree::Pages::Post,
          Spree::Pages::TaxonList,
          Spree::Pages::Custom,
          Spree::Pages::ProductDetails,
          Spree::Pages::ShopAll,
          Spree::Pages::Taxon,
          Spree::Pages::Wishlist,
          Spree::Pages::SearchResults,
          Spree::Pages::Checkout,
          Spree::Pages::Password,
          Spree::Pages::Homepage,
          Spree::Pages::Login,
          Spree::Pages::PostList,
          Spree::Pages::Account
        ]

        Rails.application.config.spree.page_sections = [
          Spree::PageSections::Breadcrumbs,
          Spree::PageSections::FeaturedPosts,
          Spree::PageSections::TaxonGrid,
          Spree::PageSections::ImageWithText,
          Spree::PageSections::FeaturedTaxon,
          Spree::PageSections::CollectionBanner,
          Spree::PageSections::ProductDetails,
          Spree::PageSections::MainPasswordFooter,
          Spree::PageSections::RelatedProducts,
          Spree::PageSections::CustomCode,
          Spree::PageSections::TaxonBanner,
          Spree::PageSections::FeaturedProduct,
          Spree::PageSections::ProductGrid,
          Spree::PageSections::ImageBanner,
          Spree::PageSections::PageTitle,
          Spree::PageSections::MainPasswordHeader,
          Spree::PageSections::PostDetails,
          Spree::PageSections::PostGrid,
          Spree::PageSections::FeaturedTaxons,
          Spree::PageSections::RichText,
          Spree::PageSections::Video,
          Spree::PageSections::Footer,
          Spree::PageSections::Newsletter,
          Spree::PageSections::Header,
          Spree::PageSections::AnnouncementBar
        ]

        Rails.application.config.spree.page_blocks = [
          Spree::PageBlocks::Link,
          Spree::PageBlocks::MegaNav,
          Spree::PageBlocks::MegaNavWithSubcategories,
          Spree::PageBlocks::Subheading,
          Spree::PageBlocks::Heading,
          Spree::PageBlocks::Nav,
          Spree::PageBlocks::Buttons,
          Spree::PageBlocks::Text,
          Spree::PageBlocks::NewsletterForm,
          Spree::PageBlocks::Image,
          Spree::PageBlocks::Products::Title,
          Spree::PageBlocks::Products::Share,
          Spree::PageBlocks::Products::Price,
          Spree::PageBlocks::Products::QuantitySelector,
          Spree::PageBlocks::Products::VariantPicker,
          Spree::PageBlocks::Products::BuyButtons
        ]
      end

      config.to_prepare do
        Dir.glob(File.join(Spree::PageBuilder::Engine.root, 'app/**/*_decorator*.rb')) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end
    end
  end

  # Backwards compatible accessors
  def self.themes
    Rails.application.config.spree.themes
  end

  def self.themes=(value)
    Rails.application.config.spree.themes = value
  end

  def self.theme_layout_sections
    Rails.application.config.spree.theme_layout_sections
  end

  def self.theme_layout_sections=(value)
    Rails.application.config.spree.theme_layout_sections = value
  end

  def self.pages
    Rails.application.config.spree.pages
  end

  def self.pages=(value)
    Rails.application.config.spree.pages = value
  end

  def self.page_sections
    Rails.application.config.spree.page_sections
  end

  def self.page_sections=(value)
    Rails.application.config.spree.page_sections = value
  end

  def self.page_blocks
    Rails.application.config.spree.page_blocks
  end

  def self.page_blocks=(value)
    Rails.application.config.spree.page_blocks = value
  end

  # Page Builder configuration accessor (groups all page builder config)
  def self.page_builder
    @page_builder ||= PageBuilderConfig.new
  end

  class PageBuilderConfig
    def themes
      Rails.application.config.spree.themes
    end

    def themes=(value)
      Rails.application.config.spree.themes = value
    end

    def theme_layout_sections
      Rails.application.config.spree.theme_layout_sections
    end

    def theme_layout_sections=(value)
      Rails.application.config.spree.theme_layout_sections = value
    end

    def pages
      Rails.application.config.spree.pages
    end

    def pages=(value)
      Rails.application.config.spree.pages = value
    end

    def page_sections
      Rails.application.config.spree.page_sections
    end

    def page_sections=(value)
      Rails.application.config.spree.page_sections = value
    end

    def page_blocks
      Rails.application.config.spree.page_blocks
    end

    def page_blocks=(value)
      Rails.application.config.spree.page_blocks = value
    end
  end
end
