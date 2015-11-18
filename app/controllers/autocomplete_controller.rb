class AutocompleteController < ApplicationController
  skip_before_action :authenticate_user!, only: [:users]

  def users
    begin
      @users =
        if params[:project_id].present?
          project = Project.find(params[:project_id])

          if can?(current_user, :read_project, project)
            project.team.users
          end
        elsif params[:group_id]
          group = Group.find(params[:group_id])

          if can?(current_user, :read_group, group)
            group.users
          end
        elsif current_user
          User.all
        end
    rescue ActiveRecord::RecordNotFound
      if current_user
        return render json: {}, status: 404
      end
    end

    if @users.nil? && current_user.nil?
      authenticate_user!
    end

    @users ||= User.none
    @users = @users.non_ldap if params[:skip_ldap] == 'true'
    @users = @users.search(params[:search]) if params[:search].present?
    @users = @users.active
    @users = @users.reorder(:name)
    if params[:push_code_to_protected_branches] && project
      @users = @users.to_a.select { |user| user.can?(:push_code_to_protected_branches, project) }.take(PER_PAGE)
    else
      @users = @users.page(params[:page]).per(PER_PAGE)
    end

    unless params[:search].present?
      # Include current user if available to filter by "Me"
      if params[:current_user] && current_user
        @users = [*@users, current_user].uniq
      end
    end

    render json: @users, only: [:name, :username, :id], methods: [:avatar_url]
  end

  def user
    @user = User.find(params[:id])
    render json: @user, only: [:name, :username, :id], methods: [:avatar_url]
  end
end
