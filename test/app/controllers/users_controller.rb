class UsersController < ActionController::Base
  prepend_before_filter :authentication
  skip_before_filter(:authentication, :only => ['login', 'login_simple', :status])
  
  def new
    render :text => "new action"
  end
  
  def login_simple
    u = User.find_by_login(params[:user][:login])
    self.current_user = u
    render :text => 'logged in'
  end
  
  def logout
    self.current_user = nil
    render :text => 'logged out'
  end
  
  def login
    authenticate do |user|
      render :text => 'logged in'
    end
  end
  
  def home
    render :text => 'home'
  end
  
  def status
    authenticated? ? "yes" : "no"
    render :text => 'status'
  end
end
