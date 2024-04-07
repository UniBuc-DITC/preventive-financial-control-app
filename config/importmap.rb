# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application'

pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'

pin 'jquery', to: 'jquery3.min.js', preload: true
pin '@rails/ujs', to: 'rails-ujs.js', preload: true

pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true

pin 'js-cookie', preload: true

pin 'vanillajs-datepicker', to: 'vanillajs-datepicker.min.js', preload: true
# Romanian locale is hardcoded in `application.js`
# pin 'vanillajs-datepicker-ro', to: 'vanillajs-datepicker-ro.js', preload: true
pin 'select2', to: 'select2.min.js', preload: true

pin_all_from 'app/javascript/controllers', under: 'controllers'
