# frozen_string_literal: true

class FinancingSource < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :expenditures, dependent: :restrict_with_error
  has_many :commitments, dependent: :restrict_with_error

  # Predicate which indicates whether this financing source
  # requires the corresponding entities to have a project category defined for them.
  def requires_project_category?
    name == 'Cercetare' || name == 'PNRR' || name == 'SEE'
  end
end
