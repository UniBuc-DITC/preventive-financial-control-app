# frozen_string_literal: true

class CreateInitialModel < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.json :value, null: false

      t.timestamps
    end

    create_table :users do |t|
      t.string :entra_user_id, null: false
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :role

      t.index :entra_user_id, unique: true

      t.timestamps
    end

    create_table :financing_sources do |t|
      t.string :name, null: false

      t.index :name, unique: true

      t.timestamps
    end

    create_table :project_categories do |t|
      t.string :name, null: false

      t.index :name, unique: true

      t.timestamps
    end

    create_table :expenditure_articles do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.index :code, unique: true

      t.timestamps
    end

    create_table :payment_methods do |t|
      t.string :name, null: false

      t.index :name, unique: true

      t.timestamps
    end

    create_table :expenditures do |t|
      t.integer :year, null: false
      t.integer :registration_number, null: false
      t.date :registration_date, null: false, default: -> { 'CURRENT_DATE' }
      t.references :financing_source, foreign_key: true, null: false
      t.references :project_category, foreign_key: true
      t.references :expenditure_article, foreign_key: true, null: false
      t.string :details, null: false, default: ''
      t.string :procurement_type, null: false, default: ''
      t.string :ordinance_number, null: false
      t.date :ordinance_date, null: false
      t.decimal :value, precision: 15, scale: 2
      t.references :payment_method, foreign_key: true, null: false
      t.string :beneficiary, null: false
      t.string :invoice, null: false, default: ''
      t.string :noncompliance, null: false, default: ''
      t.string :remarks, null: false, default: ''

      t.references :created_by_user, foreign_key: { to_table: :users }
      t.references :updated_by_user, foreign_key: { to_table: :users }

      t.index %i[year registration_number], unique: true

      t.timestamps
    end

    create_table :commitments do |t|
      t.integer :year, null: false
      t.integer :registration_number, null: false
      t.date :registration_date, null: false, default: -> { 'CURRENT_DATE' }
      t.references :financing_source, foreign_key: true, null: false
      t.references :expenditure_article, foreign_key: true, null: false
      t.string :document_number, null: false
      t.string :validity, null: false
      t.string :procurement_type, null: false, default: ''
      t.string :partner, null: false
      t.decimal :value, precision: 15, scale: 2
      t.string :noncompliance, null: false, default: ''
      t.string :remarks, null: false, default: ''

      t.references :created_by_user, foreign_key: { to_table: :users }
      t.references :updated_by_user, foreign_key: { to_table: :users }

      t.index %i[year registration_number], unique: true

      t.timestamps
    end
  end
end
