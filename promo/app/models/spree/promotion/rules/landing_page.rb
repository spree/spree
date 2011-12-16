# A rule to limit a promotion to a specific user.
module Spree
  class Promotion::Rules::LandingPage < PromotionRule
    preference :path, :string

    def eligible?(order, options = {})
      if options.has_key?(:visited_paths)
        options[:visited_paths].to_a.any? do |path|
          path == preferred_path
        end
      else
        true
      end
    end
  end
end
