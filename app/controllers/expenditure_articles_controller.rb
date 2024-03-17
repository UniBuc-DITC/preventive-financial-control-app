# frozen_string_literal: true

class ExpenditureArticlesController < ApplicationController
  before_action :require_supervisor_or_admin, only: %i[new edit create update destroy]

  def index
    @expenditure_articles = ExpenditureArticle.order(code: :asc)
  end

  def new
    @expenditure_article = ExpenditureArticle.new
  end

  def edit
    expenditure_article_id = params.require(:id)
    @expenditure_article = ExpenditureArticle.find(expenditure_article_id)
  end

  def create
    @expenditure_article = ExpenditureArticle.new expenditure_article_params

    successfully_saved = false
    ExpenditureArticle.transaction do
      successfully_saved = @expenditure_article.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :expenditure_articles,
          target_object_id: @expenditure_article.id,
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost salvat cu succes articolul de cheltuială cu codul #{@expenditure_article.code}"
      redirect_to expenditure_articles_path
    else
      flash[:alert] = 'Nu s-a putut salva noul articol de cheltuială. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    expenditure_article_id = params.require(:id)
    @expenditure_article = ExpenditureArticle.find(expenditure_article_id)

    @expenditure_article.assign_attributes expenditure_article_params

    successfully_saved = false
    ExpenditureArticle.transaction do
      successfully_saved = @expenditure_article.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :expenditure_articles,
          target_object_id: @expenditure_article.id,
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost actualizat cu succes articolul de cheltuială cu codul #{@expenditure_article.code}"
      redirect_to expenditure_articles_path
    else
      flash[:alert] = 'Nu s-au putut salva modificările la articolul de cheltuială. Verificați erorile și încercați din nou.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    expenditure_article_id = params.require(:id)
    @expenditure_article = ExpenditureArticle.find(expenditure_article_id)

    successfully_deleted = false
    ExpenditureArticle.transaction do
      successfully_deleted = @expenditure_article.destroy

      if successfully_deleted
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :delete,
          target_table: :expenditure_articles,
          target_object_id: @expenditure_article.id,
        )
      end
    end

    if successfully_deleted
      flash[:notice] = "A fost șters cu succes articolul de cheltuială cu codul #{@expenditure_article.code}"
    else
      flash[:alert] = "Nu s-a putut șterge articolul de cheltuială: #{@expenditure_article.errors.full_messages.join(', ')}."
    end

    redirect_to expenditure_articles_path
  end

  private

  def expenditure_article_params
    params.require(:expenditure_article).permit(:code, :name)
  end
end
