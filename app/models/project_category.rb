# frozen_string_literal: true

class ProjectCategory < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :expenditures, dependent: :restrict_with_error
end
