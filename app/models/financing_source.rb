# frozen_string_literal: true

class FinancingSource < ApplicationRecord
  validates :name, presence: true

  # Predicate which indicates whether this financing source
  # requires the corresponding entities to have a project category defined for them.
  def requires_project_category?
    name == 'Cercetare'
  end
end
