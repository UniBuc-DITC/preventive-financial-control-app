# frozen_string_literal: true

module ImportMatchable
  extend ActiveSupport::Concern

  included do
    normalizes :import_code, with: ->(import_code) { import_code.strip.downcase }

    scope :with_import_code, -> { where.not(import_code: '') }
  end

  def import_regexp
    @import_regexp ||= Regexp.new import_code
  end
end
