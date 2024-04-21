# frozen_string_literal: true

class FinancingSource < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip }
  normalizes :import_code, with: ->(import_code) { import_code.strip.downcase }

  has_many :expenditures, dependent: :restrict_with_error
  has_many :commitment_financing_source_associations, dependent: :restrict_with_error
  has_many :commitments, through: :commitment_financing_source_associations, dependent: :restrict_with_error

  scope :with_import_code, -> { where.not(import_code: '') }
end
