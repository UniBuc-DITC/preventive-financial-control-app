# frozen_string_literal: true

class ExpenditureArticle < ApplicationRecord
  validates :code, :name, presence: true, uniqueness: true

  normalizes :code, :name, with: ->(str) { str.strip }

  has_many :expenditures, dependent: :restrict_with_error
  has_many :commitments, dependent: :restrict_with_error
end
