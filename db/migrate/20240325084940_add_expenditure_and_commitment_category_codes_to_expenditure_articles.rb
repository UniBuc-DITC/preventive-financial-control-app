# frozen_string_literal: true

class AddExpenditureAndCommitmentCategoryCodesToExpenditureArticles < ActiveRecord::Migration[7.1]
  def change
    change_table :expenditure_articles, bulk: true do |t|
      t.string :expenditure_category_code, null: false, default: ''
      t.string :commitment_category_code, null: false, default: ''
    end
  end
end
