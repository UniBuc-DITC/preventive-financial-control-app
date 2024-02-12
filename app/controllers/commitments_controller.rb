# frozen_string_literal: true

class CommitmentsController < ApplicationController
  def index
    @commitments = Commitment.order(id: :desc)

    relation_names = %i[financing_source expenditure_article created_by_user]
    @commitments = @commitments.references(relation_names).includes(relation_names)

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @commitments = @commitments.where('registration_date >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @commitments = @commitments.where('registration_date <= ?', end_date)
    end

    if params[:expenditure_article_id].present?
      expenditure_article = ExpenditureArticle.find(params[:expenditure_article_id])
      @commitments = @commitments.where(expenditure_article:)
    end

    @paginated_commitments = @commitments.paginate(page: params[:page])
  end

  def new
    @commitment = Commitment.new
    @commitment.year = Setting.current_year
    @commitment.registration_date = Time.zone.today
    @commitment.created_by_user = current_user

    if params[:source_expenditure_id].present?
      @source_expenditure = Expenditure.find(params[:source_expenditure_id])

      @commitment.financing_source = @source_expenditure.financing_source
      @commitment.expenditure_article = @source_expenditure.expenditure_article
      @commitment.procurement_type = @source_expenditure.procurement_type
      @commitment.value = @source_expenditure.value
    end
  end

  def create
    @commitment = Commitment.new commitment_params
    @commitment.year = Setting.current_year
    @commitment.created_by_user = current_user
    @commitment.updated_by_user = current_user

    successfully_saved = false
    Commitment.transaction do
      last_registration_number = Commitment.where(year: @commitment.year).maximum(:registration_number)
      last_registration_number ||= 0
      @commitment.registration_number = last_registration_number + 1

      successfully_saved = @commitment.save
    end

    if successfully_saved
      flash[:notice] = "A fost salvat cu succes angajamentul cu numărul de înregistrare #{@commitment.registration_number}/#{@commitment.year}"
      redirect_to commitments_path
    else
      flash[:alert] = 'Nu s-a putut salva noul angajament. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def commitment_params
    params.require(:commitment).permit(
      :registration_date,
      :financing_source_id,
      :expenditure_article_id,
      :document_number,
      :validity,
      :procurement_type,
      :partner,
      :value,
      :noncompliance,
      :remarks
    )
  end
end
