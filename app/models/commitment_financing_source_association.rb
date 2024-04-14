# frozen_string_literal: true

class CommitmentFinancingSourceAssociation < ApplicationRecord
  belongs_to :commitment, touch: true
  belongs_to :financing_source
end
