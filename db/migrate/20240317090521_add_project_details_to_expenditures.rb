# frozen_string_literal: true

class AddProjectDetailsToExpenditures < ActiveRecord::Migration[7.1]
  def change
    add_column :expenditures, :project_details, :string, null: false, default: ''
  end
end
