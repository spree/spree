require 'spree/url_helpers'
module NavigationHelpers
  include Spree::UrlHelpers

  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name
    when /the home\s?page/
      spree.root_path
    when /the admin home page/
      spree.admin_path
    when /the sign in page/
      spree.new_user_session_path
    when /the sign up page/
      spree.new_user_registration_path
    when /an invalid taxon page/
      "/t/totally_bogus_taxon"


    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))

    else
      begin
        page_name =~ /the (.*) page/
        path_components = $1.split(/\s+/)
        spree.send(path_components.push('path').join('_').to_sym)
      rescue Object => e
        raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
          "Now, go and add a mapping in #{__FILE__}"
      end
    end
  end
end

World(NavigationHelpers)
