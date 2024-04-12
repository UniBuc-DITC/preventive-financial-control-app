# frozen_string_literal: true

class RenamePaymentMethodToPaymentType < ActiveRecord::Migration[7.1]
  def change
    rename_table :payment_methods, :payment_types
    rename_column :expenditures, :payment_method_id, :payment_type_id
  end
end
