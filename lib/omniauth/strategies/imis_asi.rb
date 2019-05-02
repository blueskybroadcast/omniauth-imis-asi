require 'omniauth-oauth2'
require 'builder'

module OmniAuth
  module Strategies
    class ImisAsi < OmniAuth::Strategies::OAuth2
      option :name, 'imis_asi'
      option :app_options, { app_event_id: nil }
      option :client_options, { login_page_url: 'MUST BE PROVIDED' }

      uid { info[:uid] }
      info { raw_user_info }

      def request_phase
        member_id = URI.parse(login_page_url).query.split('=').second
        return fail!(:invalid_credentials) unless member_id.present?

        redirect login_page_url
      end

      def callback_phase
        slug = request.params['slug']
        @account = Account.find_by(slug: slug)
        @app_event = @account.app_events.where(id: options.app_options.app_event_id).first_or_create(activity_type: 'sso')

        self.env['omniauth.auth'] = auth_hash
        self.env['omniauth.origin'] = '/' + slug
        self.env['omniauth.redirect_url'] = request.params['redirect_url'].presence
        self.env['omniauth.app_event_id'] = @app_event.id
        call_app!
      end

      def auth_hash
        hash = AuthHash.new(provider: name, uid: uid)
        hash.info = info
        hash
      end

      def raw_user_info
        {
          uid: request.params['uid'],
          first_name: request.params['first_name'],
          last_name: request.params['last_name'],
          email: request.params['email'],
          username: request.params['username'],
          access_codes: request.params['access_codes'].split('||'),
          custom_fields_data: request.params['custom_fields_data']
        }
      end

      private

      def login_page_url
        options.client_options.login_page_url
      end
    end
  end
end
