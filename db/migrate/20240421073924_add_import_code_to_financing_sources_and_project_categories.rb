# frozen_string_literal: true

class AddImportCodeToFinancingSourcesAndProjectCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :financing_sources, :import_code, :string, null: false, default: ''
    add_column :project_categories, :import_code, :string, null: false, default: ''
  end
end
