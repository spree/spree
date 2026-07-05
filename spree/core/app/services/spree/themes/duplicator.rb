module Spree
  module Themes
    class Duplicator
      def initialize(theme)
        @theme = theme
      end

      def duplicate
        duplicated_theme = @theme.dup
        duplicated_theme.duplicating = true
        duplicated_theme.default = false
        duplicated_theme.ready = false
        duplicated_theme.name = generate_new_name(@theme.name)
        duplicated_theme.save!

        # We need to duplicate files, pages and sections in the background
        Spree::Themes::DuplicateComponentsJob.set(wait: 5.seconds).perform_later(@theme.id, duplicated_theme.id)

        duplicated_theme
      end

      protected

      def generate_new_name(name)
        depth_of_name = name.count('#')
        highest_number_for_each_depth = Spree::Theme.where('spree_themes.name LIKE ?', "%#{name}").
                                        pluck(:name).
                                        group_by { |theme_name| theme_name.count('#') }.
                                        transform_values do |names|
                                          # ['Copy #3 of Theme', 'Copy #2 of Theme', Copy #1 of Theme'] => '3'
                                          names.map{ |n| n.split.select { |s| s.starts_with?('#') }.first&.delete('#') }.max
                                        end

        next_usable_number = highest_number_for_each_depth[depth_of_name + 1].to_i + 1

        "Copy ##{next_usable_number} of #{name}"
      end
    end
  end
end
