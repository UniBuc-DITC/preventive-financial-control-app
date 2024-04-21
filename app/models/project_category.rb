# frozen_string_literal: true

class ProjectCategory < ApplicationRecord
  include ImportMatchable

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip }

  has_many :expenditures, dependent: :restrict_with_error
end
