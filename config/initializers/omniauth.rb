# frozen_string_literal: true

# This file shouldn't be loaded when precompiling assets,
# we don't need to configure the auth system at that point.
return if ENV['RAILS_PRECOMPILE_ASSETS']

require 'omniauth/microsoft_identity_platform_auth'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer if Rails.env.development?

  provider :microsoft_identity_platform
end
