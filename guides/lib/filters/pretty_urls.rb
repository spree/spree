require 'nanoc'

class PrettyUrls < Nanoc::Filter

  identifier :pretty_urls

  def run(content, params={})

    # Allows us to use pretty urls in markdown and add .html for local viewing

    # TODO: Don't add .html when deploying to server - just use for local development since nanoc server
    # is not smart enough to understand absence of .html and still route to the correct file

    # [Hubspot Integration](hubspot_integration#foo) => [Hubspot Integration](hubspot_integration.html#foo)
    #content = content.gsub /\[(.+)\]\(([^#]+)(#\S*)?\)/ do
    # [Hubspot Integration](hubspot_integration) => [Hubspot Integration](hubspot_integration.html)
    content = content.gsub /\[([^\]]*)\]\(([^[#\)]\.]+)(#\S*)?\)/ do
      "[#{$1}](#{$2}.html#{$3})"
    end

    content
  end
end