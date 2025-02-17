# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  validates :timestamp, :action,
            :target_table, :target_object_id,
            presence: true

  enum :action, { insert: 0, update: 1, delete: 2 }, suffix: true
  enum :target_table, {
    expenditures: 0,
    commitments: 1,
    financing_sources: 2,
    project_categories: 3,
    expenditure_articles: 4,
    payment_types: 5,
    settings: 6,
    users: 7
  }

  belongs_to :user
end
