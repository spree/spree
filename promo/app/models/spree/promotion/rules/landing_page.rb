# A rule to limit a promotion to a specific user.
class Spree::Promotion::Rules::LandingPage < Spree::PromotionRule

  preference :path, :string

  def eligible?(order, options = {})
    if options.has_key?(:visited_paths)
      options[:visited_paths].to_a.any? do |path|
        path.gsub(/^\//, '') == preferred_path.gsub(/^\//, '')
      end
    else
      true
    end
  end

end

