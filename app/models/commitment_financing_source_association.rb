# frozen_string_literal: true

class CommitmentFinancingSourceAssociation < ApplicationRecord
  belongs_to :commitment
  belongs_to :financing_source
end
