require 'sinatra/base'
require 'sinatra/flash'
require 'warden'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'models/user'

# Authentication strategy
Warden::Strategies.add(:password) do
  # The valid? method sets the conditions to run the authentication strategy.
  # If the conditions are fulfilled, then the strategy is run whenever warden.authenticate! is called.
  # This method declares that if both email and password parameters are provided in a request,
  # this authentication strategy is run.
  def valid?
    user = params['user']
    user && user['username'] && user['password']
  end

  # This method actually authenticating a request.
  # Calling success! and passing the authenticated object will treat the object as authenticated
  # and serialize it into the session.
  # The fail method halts the chain and returns the specified message.
  # See https://github.com/wardencommunity/warden/wiki/Overview#failing-authentication
  def authenticate!
    user = params['user']
    return fail 'No user id provided' if user['username'].empty?

    return fail 'No password provided' if user['password'].empty?

    authenticated_user = User.first(username: user['username'])
    # If the login was successful, the `Rack::Request::Env` module, exposed as `env`,
    # will contain this key: env['rack.request.form_hash']['user'], with values:
    # {"username"=>"admin", "password"=>"admin"}
    # Access it from the Sinatra webapp as `env['warden'].user`

    return fail 'The username you entered does not exist.' if authenticated_user.nil?

    return success!(authenticated_user) if authenticated_user.authenticate(user['password'])

    fail 'Invalid username and password combination.'
  end
end

# Modular Sinatra webapp
class SinatraWardenExample < Sinatra::Base
  disable :show_errors
  disable :show_exceptions

  enable :sessions
  register Sinatra::Flash

  use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session.
    # Session values are strings; store the value of `User.id`.
    config.serialize_into_session(&:id)

    # Tell Warden how to get a `User` from a session.
    config.serialize_from_session { |id| User.get(id) }

    # `strategies` is an array of named methods with which to attempt authentication.
    # We have to define this later.
    # `action` is a route to send the user to when `warden.authenticate!`` returns false.
    # This route is defined here.
    config.scope_defaults(
      :default,
      strategies: [:password],
      action: 'auth/unauthenticated'
    )
    # When a user tries to log in and cannot, this specifies the app to send the user to.
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env, _opts|
    # Because authentication failure can happen on any request, but
    # we handle it only under "post '/auth/unauthenticated'", we need
    # to change the request method to POST
    env['REQUEST_METHOD'] = 'POST'
  end

  get '/' do
    erb :index
  end

  get '/auth/login' do
    @user = env['warden']
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!

    flash[:success] = 'Successful login'

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].logout
    flash[:success] = 'Successful logout'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] ||= env['warden.options'][:attempted_path]

    # Set the error and use a fallback if the message is not defined
    flash[:error] = env['warden.options'][:message] || 'You must log in'
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!
    erb :protected
  end
end
