# frozen_string_literal: true

class Commitment < ApplicationRecord
  validates :year, :registration_number, :registration_date,
            :document_number, :partner, :value,
            presence: true

  belongs_to :financing_source
  belongs_to :expenditure_article

  belongs_to :created_by_user, class_name: 'User'
  belongs_to :updated_by_user, class_name: 'User'
end
