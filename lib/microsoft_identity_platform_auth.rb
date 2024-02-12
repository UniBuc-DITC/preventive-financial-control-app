# frozen_string_literal: true

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
# Source: https://github.com/microsoftgraph/msgraph-sample-rubyrailsapp/blob/89cd1a1dd8a50032cf382d0ba30ee111b16704f8/graph-sample/lib/microsoft_graph_auth.rb

module OmniAuth
  module Strategies
    # Implements an OmniAuth strategy to authenticate using the Microsoft Identity Platform.
    class MicrosoftIdentityPlatform < OmniAuth::Strategies::OAuth2
      option :name, :microsoft_identity_platform

      DEFAULT_SCOPE = 'openid email profile User.Read'

      option :client_id, Rails.application.credentials.microsoft_identity_platform.client_id
      option :client_secret, Rails.application.credentials.microsoft_identity_platform.client_secret
      # Configure the Microsoft Identity Platform endpoints
      option :client_options,
             site: 'https://login.microsoftonline.com',
             authorize_url: "/#{Rails.application.credentials.microsoft_identity_platform.tenant_id}/oauth2/v2.0/authorize",
             token_url: "/#{Rails.application.credentials.microsoft_identity_platform.tenant_id}/oauth2/v2.0/token"

      option :pcke, true
      # Send the scope parameter during authorize
      option :authorize_options, [:scope]

      # Unique ID for the user is the id field
      uid { raw_info['id'] }

      # Get additional information after token is retrieved
      extra do
        {
          'raw_info' => raw_info
        }
      end

      def raw_info
        # Get user profile information from the /me endpoint
        @raw_info ||= access_token.get('https://graph.microsoft.com/v1.0/me?$select=id').parsed
      end

      def authorize_params
        super.tap do |params|
          params[:scope] = request.params['scope'] if request.params['scope']
          params[:scope] ||= DEFAULT_SCOPE
        end
      end

      # Override callback URL
      # OmniAuth by default passes the entire URL of the callback, including
      # query parameters. Azure fails validation because that doesn't match the
      # registered callback.
      def callback_url
        options[:redirect_uri] || (full_host + script_name + callback_path)
      end
    end
  end
end
