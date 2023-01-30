# Sinatra Warden Example
This article explains the basics of authentication and Rack middleware,
and in the process, builds a complete webapp with
[Sinatra](http://sinatrarb.com),
[DataMapper](http://datamapper.org), and
[Warden](http://github.com/hassox/warden).


## Audience
This article is intended for people familiar with Sinatra and DataMapper who want multiple user authentication.


## Storing Passwords
Passwords should never be stored in plain text.
If someone were to get access to your database, they'd have all the passwords.
We need to encrypt the passwords.
DataMapper supports a BCryptHash property type, which is great because
[`bcrypt`](http://en.wikipedia.org/wiki/Bcrypt) is pretty dang
[secure](http://codahale.com/how-to-safely-store-a-password/).

If you'd like to see another take on using `bcrypt`,
Github user `namelessjon` has a more complex example with some discussion
[here](https://gist.github.com/namelessjon/1039058).


## User Model
Let's get started on a `User` model.
For the rest of this section, we will be building a file named `model.rb` in stages.
The first step is to install the gems we need:

    $ gem install data_mapper
    $ gem install dm-sqlite-adapter

When installing `data_mapper`, the `bcrypt-ruby` gem is installed as a dependency.

Note: you may need to run the above gem commands with `sudo` if you are not using [virtualized Ruby instances](https://www.mslinn.com/jekyll/500-ruby-setup.html).

Open up (or create) a file named `model.rb`, `require` the gems, and set up `DataMapper`:


###### /model.rb
~~~ruby
require 'bcrypt'
require 'data_mapper'
require 'dm-sqlite-adapter'

DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")
~~~

Now lets create a `User` model.
In addition to including `DataMapper::Resource`, we will include the `BCrypt` class.
It is provided by a gem called `bcrypt-ruby`,
however it is `require`d as `bcrypt` and the class is named `BCrypt`.


###### /model.rb (cont.)
~~~ruby
#...

class User
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :username, String, :length => 3..50
  property :password, BCryptHash
end

DataMapper.finalize
DataMapper.auto_upgrade!

# end of model.rb
~~~

Lets test this code.

    $ irb
    > require './model'
    > @user = User.new(:username => "admin", :password => "test")
    > @user.save
    > @user.password
    # => "$2a$10$lKgran7g.1rSYY0M6d0V9.uLInljHgYmrr68LAj86rllmApBSqu0S"
    > @user.password == 'test'
    # => true
    > @user.password
    # => "$2a$10$lKgran7g.1rSYY0M6d0V9.uLInljHgYmrr68LAj86rllmApBSqu0S"
    > exit

Excellent, we have a `User` model that stores encrypted passwords.


## Warden, a Library for Authentication and User Sessions
Warden is [Rack](http://rack.github.com/) middleware.
Sinatra runs on Rack.
Warden lives between Rack and Sinatra.
Read an [overview of Warden](https://github.com/hassox/warden/wiki/overview).

Warden is an excellent gem for authentication with Sinatra,
however the Warden documentation is lacking, which is why I'm writing this.

Another resource is [Wiring up Warden & Sinatra](http://mikeebert.tumblr.com/post/27097231613/wiring-up-warden-sinatra),
by [Mike Ebert](https://twitter.com/mikeebert).

You may have seen that there is a gem called
[sinatra_warden](https://github.com/jsmestad/sinatra_warden).
Why am I not using it?
That gem dictates the routes for logging in and logging out,
and that logic is buried in the gem.
Instead, I prefer all the routes in my Sinatra apps to be visible at a glance, and not squirreled away.


## Installing Dependencies
I use `bundler` to build Sinatra.
It provides the `bundle` command.
This project's [Gemfile](Gemfile)
specifies its dependencies.
Pull them in with the following command:

    $ bundle install


## Modular Sinatra Webapp
The following loads the dependencies,
creates a new modular Sinatra webapp called `SinatraWardenExample`,
enables [session support](https://stackoverflow.com/a/5693760/553865) and
[Sinatra flash messages](https://rubygems.org/gems/sinatra-flash/):

###### /app.rb
~~~ruby
require 'bundler'
Bundler.require

# load the Database and User model
require './model'

class SinatraWardenExample < Sinatra::Base
  enable :sessions
  register Sinatra::Flash

#...
~~~

## Warden Setup
Most of the lines need to be explained, so I'll mark up the code with comments. This block tells Warden how to set up, using some code specific to this example, if your user model is named `User` and has a key of `id`, this block should be the same for you, otherwise, replace where you see `User` with your model's class name.

###### /app.rb (cont)
~~~ruby
  use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session.
    # Sessions can only take strings, not Ruby code, we'll store
    # the User's `id`
    config.serialize_into_session{|user| user.id }
    # Now tell Warden how to take what we've stored in the session
    # and get a User from that information.
    config.serialize_from_session{|id| User.get(id) }

    config.scope_defaults :default,
      # "strategies" is an array of named methods with which to
      # attempt authentication. We have to define this later.
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the
    # app to send the user to.
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    # Because authentication failure can happen on any request but
    # we handle it only under "post '/auth/unauthenticated'", we need
    # to change request to POST
    env['REQUEST_METHOD'] = 'POST'
    # And we need to do the following to work with  Rack::MethodOverride
    env.each do |key, value|
      env[key]['_method'] = 'post' if key == 'rack.request.form_hash'
    end
  end
~~~

### Authentication Strategy
The last part of setting up Warden is to write the code for the `:password` authentication strategy we invoked above.
In the following block,
the keys of `params` which I am using are based on the login form I made.


###### /app.rb (cont)
~~~ruby
  Warden::Strategies.add(:password) do
    def valid?
      params['user'] && params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'])

      if user.nil?
        throw(:warden, message: "The username you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        throw(:warden, message: "The username and password combination ")
      end
    end
  end
~~~

Hold on a minute.
I called an `authenticate` method on `user`.
We need to create such a method in our `User` class that accepts an attempted password.
Back in `model.rb` we'll add the following:

###### /model.rb (reopened)
~~~ruby
class User
  #...

  def authenticate(attempted_password)
    self.password == attempted_password
  end
end
~~~

Define routes to handle login, logout and a protected page.

###### /app.rb (cont)
~~~ruby
  get '/' do
    erb :index
  end

  get '/auth/login' do
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!

    flash[:success] = "Successfully logged in"

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    # env['warden'] = Warden::Proxy:3380 @config={:default_scope=>:default, :scope_defaults=>{:default=>{:action=>"auth/unauthenticated"}}, :default_strategies=>{:default=>[:password]}, :intercept_401=>true, :failure_app=>SinatraWardenExample}
    env['warden'].logout # Logout and clear the session
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?

    # Set the error and use a fallback if the message is not defined
    flash[:error] = env['warden.options'][:message] || "You must log in"
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!
    erb :protected
  end
end
~~~

## Starting The Webapp
This webapp is an example of the
[Sinatra modular-style](http://www.sinatrarb.com/intro.html#Modular%20vs.%20Classic%20Style) app.
To run a modular app, we use a file named `config.ru` (the `ru` stands for rackup).

This webapp predefines userid `admin` with password `admin`.

There are two ways to run this webapp.


### Rackup

Running `bundle install` installs the `rackup` command, which runs the webapp on port 9292 by default.
By default, `rackup` uses the `config.ru` file, like this:

~~~bash
$ rackup
# [2014-05-18 12:11:27] INFO  WEBrick 1.3.1
# [2014-05-18 12:11:27] INFO  ruby 2.0.0 (2014-02-24) [x86_64-darwin13.1.0]
# [2014-05-18 12:11:27] INFO  WEBrick::HTTPServer#start: pid=72027 port=9292
~~~

With that running in a terminal, visit http://localhost:9292 to see the webapp.


### Shotgun
There is a ruby gem called `shotgun` which is very useful in development because it will pick up changes to your Ruby files.
This means you won't need to stop and restart the server every time you modify a source file.
To use `shotgun` with our `config.ru` file, you need to tell `shotgun` which configuration file to use, like this:

~~~bash
$ shotgun config.ru
# == Shotgun/Thin on http://127.0.0.1:9393/
# >> Thin web server (v1.4.1 codename Chromeo)
# >> Maximum connections set to 1024
# >> Listening on 127.0.0.1:9393, CTRL+C to stop
~~~

`Shotgun` runs webapps on a different port than `rackup`, so if you are using `shotgun`, visit the app at http://localhost:9393.


#### Shotgun and Flash Messages
The flash plugin makes use of sessions to store messages across routes.
The sessions are stored with a "secret" that generates each time the server starts.
`Shotgun` works by restarting the server at every request,
which means the flash messages will be lost.

To enable flash messages with `shotgun`, set `:session_secret` using the following:

~~~ruby
class SinatraWardenExample < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, "supersecret"
#...
~~~

Do not store secret keys in your source code.
Instead, use an environment variable, like this:

~~~ruby
set :session_secret, ENV['SESSION_SECRET']
~~~
