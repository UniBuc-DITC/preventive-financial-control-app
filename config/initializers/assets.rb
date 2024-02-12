# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.scss, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w[jquery3.min.js bootstrap.min.js popper.js]

Rails.application.config.assets.precompile << 'rails_bootstrap_forms.css'

Rails.application.config.assets.precompile += %w[select2.min.js select2.css]

Rails.application.config.assets.precompile += %w[
  vanillajs-datepicker.min.js
  vanillajs-datepicker-bs5.min.css
]
