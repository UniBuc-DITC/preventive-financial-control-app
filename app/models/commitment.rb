# frozen_string_literal: true

class Commitment < ApplicationRecord
  validates :year, :registration_number, :registration_date, presence: true

  validates :expenditure_article, :financing_sources_ids, :document_number, :partner, :value,
            presence: true, unless: :cancelled?

  has_many :commitment_financing_source_associations, dependent: :destroy
  has_many :financing_sources, through: :commitment_financing_source_associations
  belongs_to :expenditure_article, optional: true

  belongs_to :created_by_user, class_name: 'User'
  belongs_to :updated_by_user, class_name: 'User'

  before_validation -> { @financing_sources_ids ||= financing_sources.map(&:id) }

  def financing_sources_ids
    @financing_sources_ids ||= financing_sources.pluck(&:id)
  end

  def financing_sources_ids=(ids)
    self.financing_sources = []
    @financing_sources_ids = []
    ids.each do |id|
      next if id.blank?

      financing_sources << FinancingSource.find(id)
      @financing_sources_ids << id
    end
  end

  def cancelled?
    !!cancelled
  end
end
