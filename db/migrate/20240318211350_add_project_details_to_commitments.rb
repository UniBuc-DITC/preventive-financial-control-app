# frozen_string_literal: true

class AddProjectDetailsToCommitments < ActiveRecord::Migration[7.1]
  def change
    add_column :commitments, :project_details, :string, null: false, default: ''
  end
end
