defmodule ElixirbitsWeb.Router do
  use ElixirbitsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirbitsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElixirbitsWeb do
    pipe_through :browser

    live_session :public_routes, layout: {ElixirbitsWeb.Layouts, :index} do
      live "/", IndexLive.Index, :index
    end

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/", ElixirbitsWeb.AshJsonApiRouter
  end

  scope "/dashboard", ElixirbitsWeb do
    pipe_through :browser

    live_session :dashboard_routes,
      on_mount: [{ElixirbitsWeb.LiveNavigation, :app_nav}] do
      live "/", DashboardLive, :index

      scope "/dev_panel", Dashboard do
        live "/layout_test", LayoutTestLive, :index
      end
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixirbits, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put it behind authentication and allow only admins to access it. If your application does not have an admins-only section yet, you can use Plug.BasicAuth to set up some basic authentication as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dashboard/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirbitsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
