# frozen_string_literal: true

class AddCancelledAttributeToExpendituresAndCommitments < ActiveRecord::Migration[7.1]
  def change
    add_column :expenditures, :cancelled, :boolean, null: false, default: false
    change_column_null :expenditures, :financing_source_id, true
    change_column_null :expenditures, :expenditure_article_id, true
    change_column_null :expenditures, :payment_method_id, true

    add_column :commitments, :cancelled, :boolean, null: true, default: false
    change_column_null :commitments, :expenditure_article_id, true
  end
end
