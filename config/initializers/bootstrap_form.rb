# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

BootstrapForm.configure do |c|
  c.default_form_attributes = {
    autocomplete: 'off',
    novalidate: true,
    data: { turbo: false }
  }
end
