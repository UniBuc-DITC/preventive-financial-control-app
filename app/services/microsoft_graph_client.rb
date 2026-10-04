# frozen_string_literal: true

class MicrosoftGraphClient
  def initialize
    identity_platform_credentials = Rails.application.credentials.microsoft_identity_platform

    raise StandardError, 'Microsoft Graph credentials are missing' if identity_platform_credentials.blank?

    # Authenticate using the app credentials (confidential client)
    tenant_id = identity_platform_credentials[:tenant_id]
    client_id = identity_platform_credentials[:client_id]
    client_secret = identity_platform_credentials[:client_secret]

    login_url = "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0"
    conn = Faraday.new(url: login_url) do |builder|
      # URL-encode parameters
      builder.request :url_encoded

      # Parses JSON response bodies.
      # If the response body is not valid JSON, it will raise a Faraday::ParsingError.
      builder.response :json

      # Raises an error on 4xx and 5xx responses.
      builder.response :raise_error

      # Logs requests and responses.
      # By default, it only logs the request method and URL, and the request/response headers.
      builder.response :logger
    end

    response = conn.post(
      'token',
      {
        client_id:,
        client_secret:,
        scope: 'https://graph.microsoft.com/.default',
        grant_type: 'client_credentials'
      }
    )

    unless response.status == 200
      raise StandardError.new, "Failed to authenticate against Microsoft Graph, error code: #{response.status}"
    end

    access_token = response.body['access_token']

    @connection = Faraday.new(url: 'https://graph.microsoft.com/v1.0') do |builder|
      # Sets the Authorization header with Bearer scheme.
      builder.request :authorization, 'Bearer', access_token

      # Parses JSON response bodies.
      # If the response body is not valid JSON, it will raise a Faraday::ParsingError.
      builder.response :json

      # Raises an error on 4xx and 5xx responses.
      builder.response :raise_error

      # Logs requests and responses.
      # By default, it only logs the request method and URL, and the request/response headers.
      builder.response :logger
    end
  end

  def get_user_by_id(id)
    response = @connection.get("users/#{id}")
    response.body
  rescue Faraday::ResourceNotFound
    nil
  end
end
