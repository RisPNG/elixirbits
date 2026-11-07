defmodule PoppybitWeb.Router do
  use PoppybitWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug PoppybitWeb.SessionTimeout
    plug :sign_in_with_remember_me
    plug :fetch_live_flash
    plug :put_root_layout, html: {PoppybitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :set_actor, :user
  end

  pipeline :api do
    plug :accepts, ["json"]

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Poppybit.Accounts.User,
      # if you want to require an api key to be supplied, set `required?` to true
      required?: false

    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", PoppybitWeb do
    pipe_through :browser

    ash_authentication_live_session :public_routes,
      layout: {PoppybitWeb.Layouts, :index},
      on_mount: [{PoppybitWeb.LiveUserAuth, :live_user_optional}] do
      live "/", IndexLive.Index, :index
    end

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/", PoppybitWeb.AshJsonApiRouter
  end

  scope "/dashboard", PoppybitWeb do
    pipe_through :browser

    ash_authentication_live_session :dashboard_routes,
      on_mount: [
        {PoppybitWeb.LiveUserAuth, :live_user_optional},
        {PoppybitWeb.LiveUserAuth, :app_nav}
      ] do
      live "/", DashboardLive, :index

      scope "/admin", Dashboard do
        live "/users", UserLive.Index, :index
        live "/users/create", UserLive.Entry, :create
        live "/users/:id/read", UserLive.Entry, :read
        live "/users/:id/update", UserLive.Entry, :update
        live "/roles", RoleLive.Index, :index
        live "/roles/create", RoleLive.Entry, :create
        live "/roles/:id/read", RoleLive.Entry, :read
        live "/roles/:id/update", RoleLive.Entry, :update
        live "/organization", OrganizationLive.Settings, :read
        live "/organization/update", OrganizationLive.Settings, :update
      end

      scope "/dev_panel", Dashboard do
        live "/layout_test", LayoutTestLive, :index
      end
    end

    auth_routes AuthController, Poppybit.Accounts.User, path: "/auth"
    get "/sign-out", AuthController, :sign_out

    ash_authentication_live_session :login_routes,
      on_mount: [{PoppybitWeb.LiveUserAuth, :live_no_user}] do
      live "/sign-in", Dashboard.LoginLive.Index, :sign_in
      live "/register", Dashboard.LoginLive.Register, :register
      live "/reset", Dashboard.LoginLive.ForgotPassword, :forgot_password
      live "/password-reset/:token", Dashboard.LoginLive.ResetPassword, :reset_password
      live "/magic_link/:token", Dashboard.LoginLive.MagicLink, :sign_in
    end

    ash_authentication_live_session :confirmation_routes,
      on_mount: [{PoppybitWeb.LiveUserAuth, :live_user_optional}] do
      live "/confirm_new_user/:token", Dashboard.LoginLive.Confirm, :confirm
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:poppybit, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put it behind authentication and allow only admins to access it. If your application does not have an admins-only section yet, you can use Plug.BasicAuth to set up some basic authentication as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dashboard/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PoppybitWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:poppybit, :dev_routes) do
    import AshAdmin.Router

    scope "/dashboard/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
