# frozen_string_literal: true

class Expenditure < ApplicationRecord
  validates :year, :registration_number, :registration_date, presence: true
  validates :project_category, presence: true, if: lambda {
    financing_source.present? && financing_source.requires_project_category?
  }
  validates :project_category, absence: true, if: lambda {
    financing_source.present? && !financing_source.requires_project_category?
  }
  validates :ordinance_number, :ordinance_date, :value, :beneficiary, presence: true

  belongs_to :financing_source
  belongs_to :project_category, optional: true
  belongs_to :expenditure_article
  belongs_to :payment_method

  belongs_to :created_by_user, class_name: 'User'
  belongs_to :updated_by_user, class_name: 'User'
end
