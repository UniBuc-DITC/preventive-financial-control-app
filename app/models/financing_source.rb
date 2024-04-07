# frozen_string_literal: true

class FinancingSource < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :expenditures, dependent: :restrict_with_error
  has_many :commitment_financing_source_associations, dependent: :restrict_with_error
  has_many :commitments, through: :commitment_financing_source_associations, dependent: :restrict_with_error
end
