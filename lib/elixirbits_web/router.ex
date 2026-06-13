defmodule ElixirbitsWeb.Router do
  use ElixirbitsWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug ElixirbitsWeb.SessionTimeout
    plug :sign_in_with_remember_me
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirbitsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Elixirbits.Accounts.User,
      # if you want to require an api key to be supplied, set `required?` to true
      required?: false

    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", ElixirbitsWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: [{ElixirbitsWeb.LiveUserAuth, :live_user_optional}] do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {ElixirbitsWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {ElixirbitsWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {ElixirbitsWeb.LiveUserAuth, :live_no_user}
      scope "/dev_panel", Admin do
        # live "/", DevPanelLive, :index
        live "/layout_test", LayoutTestLive, :index
        # live "/users", UsersLive, :index
      end
    end

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/json/open_api",
      default_model_expand_depth: 4

    forward "/", ElixirbitsWeb.AshJsonApiRouter
  end

  scope "/", ElixirbitsWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, Elixirbits.Accounts.User, path: "/auth"
    get "/sign-out", AuthController, :sign_out

    ash_authentication_live_session :login_routes,
      on_mount: [{ElixirbitsWeb.LiveUserAuth, :live_no_user}] do
      live "/sign-in", LoginLive.Index, :sign_in
      live "/register", LoginLive.Register, :register
      live "/reset", LoginLive.ForgotPassword, :forgot_password
      live "/password-reset/:token", LoginLive.ResetPassword, :reset_password
      live "/magic_link/:token", LoginLive.MagicLink, :sign_in
    end

    ash_authentication_live_session :confirmation_routes,
      on_mount: [{ElixirbitsWeb.LiveUserAuth, :live_user_optional}] do
      live "/confirm_new_user/:token", LoginLive.Confirm, :confirm
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ElixirbitsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixirbits, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirbitsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:elixirbits, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
