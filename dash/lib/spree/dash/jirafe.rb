module Spree
  module Dash
    class JirafeException < Exception; end
    class JirafeUnavailable < Exception; end

    class Jirafe
      include HTTParty
      base_uri 'https://api.jirafe.com/v1'
      format :json

      class << self
        def register(store)
          validate_required_keys! store
          store = register_application(store)
          store = synchronize_resources(store)
        end

        def validate_required_keys!(store)
          [:first_name, :url, :email, :currency, :time_zone, :name].each do |key|
            unless store[key].present?
              raise JirafeException, "#{key.to_s.titleize} is required"
            end
          end
        end

        def register_application(store)
          return if store[:app_id].present? && store[:app_token].present?

          options = {
            :body => {
              :name => store[:name],
              :url => store[:url]
            }
          }
          response = post '/applications', options
          if response.code == 200
            store[:app_id] = response['app_id']
            store[:app_token] = response['token']
            return store
          elsif response.code == 503
            raise JirafeUnavailable, I18n.t(:'spree.dash.jirafe.currently_unavailable')
          else
            raise JirafeException, 'unable to create jirafe application'
          end
        end

        def synchronize_resources(store)
          return unless store.has_key?(:app_id) and store.has_key?(:app_token)

          options = {
            :headers => { 'Content-type' => 'application/json' },
            :query => { :token => store[:app_token] },
            :body => {
              :sites => [{ :description => store[:name],
                        :url => store[:url],
                        :currency => store[:currency],
                        :timezone => store[:time_zone],
                        :external_id => 1,
                        :site_id => store[:site_id] }],
              :platform_type => 'spree',
              :users => users_hash
            }.to_json
          }
          response = post "/applications/#{store[:app_id]}/resources", options
          raise JirafeException, 'unable to synchronize store' unless response.code == 200 &&
                                                                      response['sites'].present? &&
                                                                      response['users'].present?
          store[:site_id] = response["sites"].first["site_id"]
          store[:site_token] = response["users"].first["token"]
          store
        end

        def users_hash
          users = []
          Spree.user_class.includes(:spree_roles).where("spree_roles.name = 'admin'").each do |user|
            users << {
              :email => user.email,
              :first_name => 'Spree',
              :last_name => 'User'
            }
          end
          users
        end
      end
    end
  end
end
