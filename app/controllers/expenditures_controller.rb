# frozen_string_literal: true

class ExpendituresController < ApplicationController
  def index
    @expenditures = Expenditure.order(id: :desc)

    relation_names = %i[financing_source project_category expenditure_article payment_method created_by_user]
    @expenditures = @expenditures.references(relation_names).includes(relation_names)

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date <= ?', end_date)
    end

    if params[:expenditure_article_id].present?
      expenditure_article = ExpenditureArticle.find(params[:expenditure_article_id])
      @expenditures = @expenditures.where(expenditure_article:)
    end

    @paginated_expenditures = @expenditures.paginate(page: params[:page], per_page: 5)
  end

  def new
    @expenditure = Expenditure.new
    @expenditure.year = Setting.current_year
    @expenditure.registration_date = Time.zone.today
    @expenditure.created_by_user = current_user
  end

  def create
    @expenditure = Expenditure.new expenditure_params
    @expenditure.year = Setting.current_year
    @expenditure.created_by_user = current_user
    @expenditure.updated_by_user = current_user

    successfully_saved = false
    Expenditure.transaction do
      last_registration_number = Expenditure.where(year: @expenditure.year).maximum(:registration_number)
      last_registration_number ||= 0
      @expenditure.registration_number = last_registration_number + 1

      successfully_saved = @expenditure.save
    end

    if successfully_saved
      flash[:notice] = "A fost salvată cu succes cheltuiala cu numărul de înregistrare #{@expenditure.registration_number}/#{@expenditure.year}"
      redirect_to expenditures_path
    else
      flash[:alert] = 'Nu s-a putut salva noua cheltuială. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def expenditure_params
    params.require(:expenditure).permit(
      :registration_date,
      :financing_source_id,
      :project_category_id,
      :expenditure_article_id,
      :details,
      :procurement_type,
      :ordinance_number,
      :ordinance_date,
      :value,
      :payment_method_id,
      :beneficiary,
      :invoice,
      :noncompliance,
      :remarks
    )
  end
end
