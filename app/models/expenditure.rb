# frozen_string_literal: true

class Expenditure < ApplicationRecord
  validates :year, :registration_number, :registration_date, presence: true
  validates :financing_source, :expenditure_article, :payment_type, :value,
            presence: true, unless: :cancelled?
  # Some imported records might not have a beneficiary listed
  validates :beneficiary, presence: true, unless: -> { cancelled? || imported? }

  validate :ordinance_date_before_registration_date, on: :create, unless: -> { cancelled? || imported? }

  belongs_to :financing_source, optional: true
  belongs_to :project_category, optional: true
  belongs_to :expenditure_article, optional: true
  belongs_to :payment_type, optional: true

  belongs_to :created_by_user, class_name: 'User'
  belongs_to :updated_by_user, class_name: 'User'

  attr_accessor :imported

  def imported?
    !!@imported
  end

  def cancelled?
    !!cancelled
  end

  private

  def ordinance_date_before_registration_date
    return unless registration_date.present? && ordinance_date.present?
    return if ordinance_date <= registration_date

    errors.add(:registration_date, 'nu poate fi înainte de data ordonanțării')
  end
end
