require'httparty'

module Spree
  class Alert
    def self.current(host)
      params = {
        :version => Spree.version,
        :name => Spree::Config[:site_name],
        :host => host,
        :rails_env => Rails.env,
        :rails_version => Rails.version
      }

      HTTParty.get("http://alerts.spreecommerce.com/alerts.json", :body => params).parsed_response
    end
  end
end
