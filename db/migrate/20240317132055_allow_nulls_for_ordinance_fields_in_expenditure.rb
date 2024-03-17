# frozen_string_literal: true

class AllowNullsForOrdinanceFieldsInExpenditure < ActiveRecord::Migration[7.1]
  def change
    change_column_null :expenditures, :ordinance_number, true
    change_column_null :expenditures, :ordinance_date, true
  end
end
