# frozen_string_literal: true

class Expenditure < ApplicationRecord
  validates :year, :registration_number, :registration_date, presence: true
  validates :project_category, presence: true, if: lambda {
    financing_source.present? && financing_source.requires_project_category?
  }
  validates :value, :beneficiary, presence: true

  # TODO: check why this fails for row 13 in Excel import
  # validate :ordinance_date_before_registration_date

  belongs_to :financing_source
  belongs_to :project_category, optional: true
  belongs_to :expenditure_article
  belongs_to :payment_method

  belongs_to :created_by_user, class_name: 'User'
  belongs_to :updated_by_user, class_name: 'User'

  private

  def ordinance_date_before_registration_date
    return unless registration_date.present? && ordinance_date.present?
    return if ordinance_date <= registration_date

    errors.add(:registration_date, 'nu poate fi înainte de data ordonanțării')
  end
end
