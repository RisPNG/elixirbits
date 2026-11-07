defmodule PoppybitWeb.PageController do
  use PoppybitWeb, :controller

  plug :put_layout, html: {PoppybitWeb.Layouts, :public}

  def home(conn, _params) do
    conn
    |> assign(:organization, Poppybit.Organizations.OrganizationService.current_organization!())
    |> render(:home, page_title: "Home")
  end
end
