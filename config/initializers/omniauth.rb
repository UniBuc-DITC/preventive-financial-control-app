# frozen_string_literal: true

# This file shouldn't be loaded when precompiling assets,
# we don't need to configure the auth system at that point.
return if ENV['RAILS_PRECOMPILE_ASSETS']

require 'omniauth/microsoft_identity_platform_auth'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer, fields: %i[email first_name last_name role], uid_field: :email if Rails.env.local?

  provider :microsoft_identity_platform if Rails.application.credentials.microsoft_identity_platform.present?
end
