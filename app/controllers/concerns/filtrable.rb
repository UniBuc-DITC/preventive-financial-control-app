# frozen_string_literal: true

module Filtrable
  extend ActiveSupport::Concern

  # Parse a parameter which is supposed to have an array of values,
  # returning an empty array if it's missing and skipping over empty values within it.
  def parse_array_parameter(key)
    values = params[key]
    if values.present?
      values.select(&:present?)
    else
      []
    end
  end

  included do
    def apply_field_value_filter(collection, field_name, param_key = nil)
      param_key ||= field_name

      param_value = params[param_key]
      if param_value.present?
        collection = collection.where("#{field_name}": param_value)
        @any_filters_applied = true
      end

      collection
    end

    def apply_string_field_filter(collection, field_name, param_key = nil)
      param_key ||= field_name

      param_value = params[param_key]
      if param_value.present?
        collection = collection.where("#{field_name} ILIKE ?", "%#{param_value}%")
        @any_filters_applied = true
      end

      collection
    end

    def apply_value_range_filter(collection)
      if params[:min_value].present?
        collection = collection.where(value: params[:min_value]..)
        @any_filters_applied = true
      end

      if params[:max_value].present?
        collection = collection.where(value: ..params[:max_value])
        @any_filters_applied = true
      end

      collection
    end

    def apply_ids_filter(collection, instance_variable_name, field_name, param_key = nil)
      param_key ||= instance_variable_name

      param_value = parse_array_parameter param_key
      unless param_value.empty?
        collection = collection.where("#{field_name}": param_value)
        @any_filters_applied = true
      end

      instance_variable_set("@#{instance_variable_name}", param_value)

      collection
    end

    def apply_exclude_cash_receipts_filter(collection)
      if params[:exclude_cash_receipts].present?
        exclude_cash_receipts = ActiveRecord::Type::Boolean.new.cast(params[:exclude_cash_receipts])
        if exclude_cash_receipts
          receipts_expenditure_article = ExpenditureArticle.find_by(code: '12')
          if receipts_expenditure_article.present?
            collection = collection.where.not(expenditure_article: receipts_expenditure_article)
            @any_filters_applied = true
          else
            flash[:alert] =
              'Nu s-a putut aplica filtrul deoarece nu este definit articolul de cheltuială cu codul 12, "Încasări"'
          end
        end
      end

      collection
    end

    # Filters a collection by the user who created the entities,
    # based on a list of user IDs received from the request.
    def apply_created_by_user_ids_filter(collection)
      apply_ids_filter collection,
                       :created_by_user_ids,
                       :created_by_user_id
    end

    # Filters a collection by the user who last modified the entities,
    # based on a list of user IDs received from the request.
    def apply_updated_by_user_ids_filter(collection)
      apply_ids_filter collection,
                       :updated_by_user_ids,
                       :updated_by_user_id
    end
  end
end
